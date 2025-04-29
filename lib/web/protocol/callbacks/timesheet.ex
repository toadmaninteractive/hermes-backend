defmodule WebProtocol.HermesTimesheetService.Impl do

  @behaviour WebProtocol.HermesTimesheetService

  # ----------------------------------------------------------------------------

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

  def router() do
    quote do
      match "/api/timesheet/bulk/allocate", to: WebProtocol.HermesTimesheetService.TimesheetBulkAllocate
      match "/api/timesheet/bulk/off", to: WebProtocol.HermesTimesheetService.TimesheetBulkTimeOff
      match "/api/timesheet/bulk/protect", to: WebProtocol.HermesTimesheetService.TimesheetBulkProtect
      match "/api/timesheet/bulk/reset", to: WebProtocol.HermesTimesheetService.TimesheetBulkReset
      match "/api/timesheet/bulk/unprotect", to: WebProtocol.HermesTimesheetService.TimesheetBulkUnprotect
      match "/api/timesheet/cell/:cell_id", to: WebProtocol.HermesTimesheetService.TimesheetCell
      match "/api/timesheet/monthly/:year/:month/employee/:personnel_id", to: WebProtocol.HermesTimesheetService.MonthlyEmployeeTimesheet
      match "/api/timesheet/monthly/:year/:month/employee/:personnel_id/protect", to: WebProtocol.HermesTimesheetService.TimesheetCellProtectMonthForEmployee
      match "/api/timesheet/monthly/:year/:month/everyone", to: WebProtocol.HermesTimesheetService.MonthlyEveryoneTimesheet
      match "/api/timesheet/monthly/:year/:month/office/:office_id", to: WebProtocol.HermesTimesheetService.MonthlyOfficeTimesheet
      match "/api/timesheet/monthly/:year/:month/project/:project_id", to: WebProtocol.HermesTimesheetService.MonthlyProjectTimesheet
      match "/api/timesheet/monthly/:year/:month/regenerate", to: WebProtocol.HermesTimesheetService.TimesheetRegenerate
      match "/api/timesheet/monthly/:year/:month/team/:team_id", to: WebProtocol.HermesTimesheetService.MonthlyTeamTimesheet
    end
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get a timesheet cell
  """
  @spec get_timesheet_cell(
    cell_id :: integer,
    session :: any()
  ) :: DbProtocol.TimesheetCell.t()
  @impl true
  def get_timesheet_cell(
    cell_id,
    session
  ) when
    is_integer(cell_id)
  do
    unless Hermes.can_get_timesheet?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_timesheet_cell!(cell_id)
  end

  # ----------------------------------------------------------------------------

  @doc """
  Allocate a lot of timesheet cells for a project
  """
  @spec allocate_timesheet_cell_bulk(
    request_content :: WebProtocol.BulkTimesheetAllocate.t(),
    session :: any()
  ) :: [DbProtocol.TimesheetCell.t()]
  @impl true
  def allocate_timesheet_cell_bulk(
    request_content,
    session
  ) when
    is_struct(request_content, WebProtocol.BulkTimesheetAllocate)
  do
    unless Hermes.can_get_timesheet?(session), do: raise DataProtocol.ForbiddenError
    %{cells: selector, project_id: project_id} = request_content
    selector = case selector do
      {:ids, cell_ids} when is_list(cell_ids) ->
        [{:ids, cell_ids}]
      {:months, months} when is_list(months) ->
        months |> Enum.map(fn %{year: year, month: month} -> {:month, year, month} end)
      # TODO: remove after Igor for TS has unions
      %{ids: cell_ids} when is_list(cell_ids) ->
        [{:ids, cell_ids}]
    end
    cells = Hermes.update_timesheet!([{:custom, is_protected: false} | selector], %{project_id: project_id, time_off: nil})
    log_user_action(session, :allocate, cells)
    cells
  end

  # ----------------------------------------------------------------------------

  @doc """
  Reset a lot of timesheet cells for a project
  """
  @spec reset_timesheet_cell_bulk(
    request_content :: WebProtocol.BulkTimesheetAction.t(),
    session :: any()
  ) :: [DbProtocol.TimesheetCell.t()]
  @impl true
  def reset_timesheet_cell_bulk(
    request_content,
    session
  ) when
    is_struct(request_content, WebProtocol.BulkTimesheetAction)
  do
    unless Hermes.can_get_timesheet?(session), do: raise DataProtocol.ForbiddenError
    %{cells: selector} = request_content
    selector = case selector do
      {:ids, cell_ids} when is_list(cell_ids) ->
        [{:ids, cell_ids}]
      {:months, months} when is_list(months) ->
        months |> Enum.map(fn %{year: year, month: month} -> {:month, year, month} end)
      # TODO: remove after Igor for TS has unions
      %{ids: cell_ids} when is_list(cell_ids) ->
        [{:ids, cell_ids}]
    end
    cells = Hermes.update_timesheet!([:not_empty, {:custom, is_protected: false} | selector], %{project_id: nil, time_off: nil})
    log_user_action(session, :deallocate, cells)
    cells
  end

  # ----------------------------------------------------------------------------

  @doc """
  Set a time_off to a lot of timesheet cells
  """
  @spec set_timesheet_cell_off_bulk(
    request_content :: WebProtocol.BulkTimesheetTimeOff.t(),
    session :: any()
  ) :: [DbProtocol.TimesheetCell.t()]
  @impl true
  def set_timesheet_cell_off_bulk(
    request_content,
    session
  ) when
    is_struct(request_content, WebProtocol.BulkTimesheetTimeOff)
  do
    unless Hermes.can_get_timesheet?(session), do: raise DataProtocol.ForbiddenError
    %{cells: selector, time_off: time_off} = request_content
    selector = case selector do
      {:ids, cell_ids} when is_list(cell_ids) ->
        [{:ids, cell_ids}]
      {:months, months} when is_list(months) ->
        months |> Enum.map(fn %{year: year, month: month} -> {:month, year, month} end)
      # TODO: remove after Igor for TS has unions
      %{ids: cell_ids} when is_list(cell_ids) ->
        [{:ids, cell_ids}]
    end
    cells = Hermes.update_timesheet!([{:custom, is_protected: false} | selector], %{project_id: nil, time_off: time_off})
    log_user_action(session, :absence, cells)
    cells
  end

  # ----------------------------------------------------------------------------

  @doc """
  Protect a lot of timesheet cells from changes
  """
  @spec protect_timesheet_cell_bulk(
    request_content :: WebProtocol.BulkTimesheetProtect.t(),
    session :: any()
  ) :: [DbProtocol.TimesheetCell.t()]
  @impl true
  def protect_timesheet_cell_bulk(
    request_content,
    session
  ) when
    is_struct(request_content, WebProtocol.BulkTimesheetProtect)
  do
    unless Hermes.can_protect_timesheet?(session), do: raise DataProtocol.ForbiddenError
    %{cells: selector, comment: comment} = request_content
    selector = case selector do
      {:ids, cell_ids} when is_list(cell_ids) ->
        [{:ids, cell_ids}]
      {:months, months} when is_list(months) ->
        months |> Enum.map(fn %{year: year, month: month} -> {:month, year, month} end)
      # TODO: remove after Igor for TS has unions
      %{ids: cell_ids} when is_list(cell_ids) ->
        [{:ids, cell_ids}]
    end
    cells = Hermes.update_timesheet!([{:custom, is_protected: false} | selector], %{is_protected: true})
    log_user_action(session, :protect, cells, %{comment: comment})
    cells
  end

  # ----------------------------------------------------------------------------

  @doc """
  Remove protection from a lot of timesheet cells
  """
  @spec unprotect_timesheet_cell_bulk(
    request_content :: WebProtocol.BulkTimesheetProtect.t(),
    session :: any()
  ) :: [DbProtocol.TimesheetCell.t()]
  @impl true
  def unprotect_timesheet_cell_bulk(
    request_content,
    session
  ) when
    is_struct(request_content, WebProtocol.BulkTimesheetProtect)
  do
    unless Hermes.can_unprotect_timesheet?(session), do: raise DataProtocol.ForbiddenError
    %{cells: selector, comment: comment} = request_content
    selector = case selector do
      {:ids, cell_ids} when is_list(cell_ids) ->
        [{:ids, cell_ids}]
      {:months, months} when is_list(months) ->
        months |> Enum.map(fn %{year: year, month: month} -> {:month, year, month} end)
      # TODO: remove after Igor for TS has unions
      %{ids: cell_ids} when is_list(cell_ids) ->
        [{:ids, cell_ids}]
    end
    cells = Hermes.update_timesheet!([{:custom, is_protected: true} | selector], %{is_protected: false})
    log_user_action(session, :unprotect, cells, %{comment: comment})
    cells
  end

  # ----------------------------------------------------------------------------

  @doc """
  Regenerate timesheet cells for all employees for the period specified
  """
  @spec regenerate_timesheet_cells(
    request_content :: CommonProtocol.Empty.t(),
    year :: integer,
    month :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def regenerate_timesheet_cells(
    request_content,
    year,
    month,
    session
  ) when
    is_struct(request_content, CommonProtocol.Empty) and
    is_integer(year) and
    is_integer(month)
  do
    unless Hermes.can_regenerate_timesheet?(session), do: raise DataProtocol.ForbiddenError
    Hermes.ensure_cells(year, month)
    log_user_action(session, :regenerate, [], %{year: year, month: month})
    %DataProtocol.GenericResponse{result: true}
  end

  # ----------------------------------------------------------------------------

  @doc """
  Protect a monthly range of timesheet cells for particular employee from changes
  """
  @spec protect_timesheet_month_for_employee(
    request_content :: CommonProtocol.Empty.t(),
    year :: integer,
    month :: integer,
    personnel_id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def protect_timesheet_month_for_employee(
    request_content,
    year,
    month,
    personnel_id,
    session
  ) when
    is_struct(request_content, CommonProtocol.Empty) and
    is_integer(year) and
    is_integer(month) and
    is_integer(personnel_id)
  do
    unless Hermes.can_protect_timesheet?(session), do: raise DataProtocol.ForbiddenError
    cells = Hermes.update_timesheet!([{:employees, [personnel_id]}, {:month, year, month}, {:custom, is_protected: false}], %{is_protected: true})
    log_user_action(session, :protect, cells)
    %DataProtocol.GenericResponse{result: true}
  end

  # ----------------------------------------------------------------------------

  @doc """
  Remove protection from a monthly range of timesheet cells for particular employee
  """
  @spec unprotect_timesheet_month_for_employee(
    year :: integer,
    month :: integer,
    personnel_id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def unprotect_timesheet_month_for_employee(
    year,
    month,
    personnel_id,
    session
  ) when
    is_integer(year) and
    is_integer(month) and
    is_integer(personnel_id)
  do
    unless Hermes.can_unprotect_timesheet?(session), do: raise DataProtocol.ForbiddenError
    cells = Hermes.update_timesheet!([{:employees, [personnel_id]}, {:month, year, month}, {:custom, is_protected: true}], %{is_protected: false})
    log_user_action(session, :unprotect, cells)
    %DataProtocol.GenericResponse{result: true}
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get monthly timesheet for specified year and month and employee
  """
  @spec get_monthly_timesheet_for_employee(
    year :: integer,
    month :: integer,
    personnel_id :: integer,
    session :: any()
  ) :: WebProtocol.MonthlyEmployeeTimesheet.t()
  @impl true
  def get_monthly_timesheet_for_employee(
    year,
    month,
    personnel_id,
    session
  ) when
    is_integer(year) and
    is_integer(month) and
    is_integer(personnel_id)
  do
    unless Hermes.can_get_timesheet?(session, personnel: personnel_id), do: raise DataProtocol.ForbiddenError
    Hermes.get_monthly_timesheet_for_employee(personnel_id, year, month)
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get monthly timesheet for specified year and month and project
  """
  @spec get_monthly_timesheet_for_project(
    year :: integer,
    month :: integer,
    project_id :: integer,
    session :: any()
  ) :: DataProtocol.Collection.t(WebProtocol.MonthlyEmployeeTimesheet.t())
  @impl true
  def get_monthly_timesheet_for_project(
    year,
    month,
    project_id,
    session
  ) when
    is_integer(year) and
    is_integer(month) and
    is_integer(project_id)
  do
    unless Hermes.can_get_timesheet?(session, project: project_id), do: raise DataProtocol.ForbiddenError
    items = Hermes.get_monthly_timesheet_for_project(project_id, year, month)
    struct!(DataProtocol.Collection, %{items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get monthly timesheet for specified year and month and office
  """
  @spec get_monthly_timesheet_for_office(
    year :: integer,
    month :: integer,
    office_id :: integer,
    session :: any()
  ) :: DataProtocol.Collection.t(WebProtocol.MonthlyEmployeeTimesheet.t())
  @impl true
  def get_monthly_timesheet_for_office(
    year,
    month,
    office_id,
    session
  ) when
    is_integer(year) and
    is_integer(month) and
    is_integer(office_id)
  do
    unless Hermes.can_get_timesheet?(session, office: office_id), do: raise DataProtocol.ForbiddenError
    items = Hermes.get_monthly_timesheet_for_office(office_id, year, month)
    struct!(DataProtocol.Collection, %{items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get monthly timesheet for specified year and month and team
  """
  @spec get_monthly_timesheet_for_team(
    year :: integer,
    month :: integer,
    team_id :: integer,
    session :: any()
  ) :: DataProtocol.Collection.t(WebProtocol.MonthlyEmployeeTimesheet.t())
  @impl true
  def get_monthly_timesheet_for_team(
    year,
    month,
    team_id,
    session
  ) when
    is_integer(year) and
    is_integer(month) and
    is_integer(team_id)
  do
    unless Hermes.can_get_timesheet?(session, team: team_id), do: raise DataProtocol.ForbiddenError
    items = Hermes.get_monthly_timesheet_for_team(team_id, year, month)
    struct!(DataProtocol.Collection, %{items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get monthly timesheet for specified year and month for everyone
  """
  @spec get_monthly_timesheet_for_everyone(
    year :: integer,
    month :: integer,
    session :: any()
  ) :: DataProtocol.Collection.t(WebProtocol.MonthlyEmployeeTimesheet.t())
  @impl true
  def get_monthly_timesheet_for_everyone(
    year,
    month,
    session
  ) when
    is_integer(year) and
    is_integer(month)
  do
    unless Hermes.can_get_timesheet?(session), do: raise DataProtocol.ForbiddenError
    items = Hermes.get_monthly_timesheet_for_everyone(year, month)
    struct!(DataProtocol.Collection, %{items: items})
  end

  # ----------------------------------------------------------------------------
  # internal functions
  # ----------------------------------------------------------------------------

  defp log_user_action(session, action, cells, aux \\ %{}) do
    action_txid = Ecto.UUID.generate()
    all_affected_users = cells
      |> Enum.reduce(%{}, fn cell, acc ->
        acc |> Map.put(cell.personnel_id, Util.take(cell, [id: :personnel_id, name: :personnel_name, username: :personnel_username]))
      end)
    affects_groups = cells
      |> Enum.group_by(& &1.personnel_id, & &1.cell_date)
      |> Enum.group_by(
        fn {_personnel_id, dates} -> dates end,
        fn {personnel_id, _dates} -> all_affected_users[personnel_id] end
      )
    # IO.inspect({:gr, affects_groups})
    project = cells |> Enum.map(& Util.take(&1, [id: :project_id, title: :project_name])) |> Enum.uniq() |> List.first()
    absence = cells |> Enum.map(& Util.take(&1, [code: :time_off])) |> Enum.uniq() |> List.first()
    for {dates, affects} <- affects_groups do
      # IO.inspect({:log_user_action, action, opts})
      for whence <- Util.Date.split_to_months(dates) do
        data = case action do
          :allocate ->
            %{project: project}
          :absence ->
            %{absence: absence}
          _ ->
            %{}
        end
        Hermes.log_user_action(session, Map.merge(aux, %{
          operation: action,
          entity: :timecell,
          is_bulk: length(cells) > 1,
          properties: %{
            action_txid: action_txid,
            data: data,
            when: whence,
            affects: affects,
          }
        }))
      end
    end
  end

end
