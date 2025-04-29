defmodule WebProtocol.HermesHistoryService.Impl do

  require WebProtocol.HistoryEntryOrderBy
  require DataProtocol.OrderDirection

  @behaviour WebProtocol.HermesHistoryService

  # ----------------------------------------------------------------------------

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

  def router() do
    quote do
      match "/api/history/role/employee/:personnel_id", to: WebProtocol.HermesHistoryService.EmployeeRoleChangeHistory
      match "/api/history/role/office/:office_id", to: WebProtocol.HermesHistoryService.EmployeeRoleChangeHistoryForOffice
      match "/api/history/timesheet/cells", to: WebProtocol.HermesHistoryService.CustomTimesheetHistory
      match "/api/history/timesheet/monthly/:year/:month/employee/:personnel_id", to: WebProtocol.HermesHistoryService.MonthlyEmployeeTimesheetHistory
      match "/api/history/timesheet/monthly/:year/:month/office/:office_id", to: WebProtocol.HermesHistoryService.MonthlyOfficeTimesheetHistory
      match "/api/history/timesheet/monthly/:year/:month/project/:project_id", to: WebProtocol.HermesHistoryService.MonthlyProjectTimesheetHistory
      match "/api/history/timesheet/monthly/:year/:month/team/:team_id", to: WebProtocol.HermesHistoryService.MonthlyTeamTimesheetHistory
      match "/api/history/:entity", to: WebProtocol.HermesHistoryService.History
    end
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get action history
  """
  @spec get_history(
    entity :: String.t(),
    needle :: String.t() | nil,
    order_by :: WebProtocol.HistoryEntryOrderBy.t(),
    order_dir :: DataProtocol.OrderDirection.t(),
    offset :: integer,
    limit :: integer,
    session :: any()
  ) :: DataProtocol.CollectionSlice.t(DbProtocol.HistoryEntry.t())
  @impl true
  def get_history(
    entity,
    needle,
    order_by,
    order_dir,
    offset,
    limit,
    session
  ) when
    is_binary(entity) and
    (is_binary(needle) or needle === nil) and
    WebProtocol.HistoryEntryOrderBy.is_history_entry_order_by(order_by) and
    DataProtocol.OrderDirection.is_order_direction(order_dir) and
    is_integer(offset) and
    is_integer(limit)
  do
    unless Hermes.can_get_timesheet?(session), do: raise DataProtocol.ForbiddenError
    needle = needle && "#{needle}"
    total = Hermes.count_history(entity: entity, operation: needle)
    items = Hermes.get_history(entity: entity, operation: needle, order_by: [{order_dir, order_by}], offset: offset, limit: limit)
    struct!(DataProtocol.CollectionSlice, %{total: total, items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get employee role change history
  """
  @spec get_employee_role_change_history(
    personnel_id :: integer,
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.HistoryEntry.t())
  @impl true
  def get_employee_role_change_history(
    personnel_id,
    session
  ) when
    is_integer(personnel_id)
  do
    unless Hermes.can_get_timesheet?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_employee!(personnel_id)
    items = Hermes.get_role_history_for_employee!(personnel_id)
    struct!(DataProtocol.Collection, %{items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get employee role change history for particular office
  """
  @spec get_employee_role_change_history_for_office(
    office_id :: integer,
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.HistoryEntry.t())
  @impl true
  def get_employee_role_change_history_for_office(
    office_id,
    session
  ) when
    is_integer(office_id)
  do
    unless Hermes.can_get_timesheet?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_office!(office_id)
    items = Hermes.get_role_history_for_office!(office_id)
    struct!(DataProtocol.Collection, %{items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get action history for particular timesheet сells
  """
  @spec get_custom_timesheet_history(
    cell_ids :: [integer],
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.HistoryEntry.t())
  @impl true
  def get_custom_timesheet_history(
    cell_ids,
    session
  ) when
    is_list(cell_ids)
  do
    unless Hermes.can_get_timesheet?(session), do: raise DataProtocol.ForbiddenError
    # TODO: optimize!
    items = Hermes.get_timesheet_cells!([{:ids, cell_ids}])
      |> Enum.map(fn %{cell_date: cell_date, personnel_id: personnel_id} ->
        %{year: year, month: month, day: day} = cell_date
        Hermes.get_timesheet_history_for_day_employee(year, month, day, personnel_id)
          # |> Enum.map(fn %{properties: %{"when" => whence, "affects" => affects} = properties} = record ->
          #   %{record | properties: %{properties | "when" => %{whence | "days" => [day]}, "affects" => Enum.filter(affects, & &1["id"] == personnel_id)}}
          # end)
      end)
      |> List.flatten()
      |> Enum.uniq()
    # IO.inspect({:ch, length(items), items |> Enum.group_by(& &1.id)})
    struct!(DataProtocol.Collection, %{items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get monthly history of timesheet for specified year and month and employee
  """
  @spec get_monthly_timesheet_history_for_employee(
    year :: integer,
    month :: integer,
    personnel_id :: integer,
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.HistoryEntry.t())
  @impl true
  def get_monthly_timesheet_history_for_employee(
    year,
    month,
    personnel_id,
    session
  ) when
    is_integer(year) and
    is_integer(month) and
    is_integer(personnel_id)
  do
    unless Hermes.can_get_timesheet?(session), do: raise DataProtocol.ForbiddenError
    items = Hermes.get_monthly_timesheet_history_for_employee(year, month, personnel_id)
    struct!(DataProtocol.Collection, %{items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get monthly history of timesheet for specified year and month and project
  """
  @spec get_monthly_timesheet_history_for_project(
    year :: integer,
    month :: integer,
    project_id :: integer,
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.HistoryEntry.t())
  @impl true
  def get_monthly_timesheet_history_for_project(
    year,
    month,
    project_id,
    session
  ) when
    is_integer(year) and
    is_integer(month) and
    is_integer(project_id)
  do
    unless Hermes.can_get_timesheet?(session), do: raise DataProtocol.ForbiddenError
    items = Hermes.get_monthly_timesheet_history_for_project(year, month, project_id)
    struct!(DataProtocol.Collection, %{items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get monthly history of timesheet for specified year and month and office
  """
  @spec get_monthly_timesheet_history_for_office(
    year :: integer,
    month :: integer,
    office_id :: integer,
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.HistoryEntry.t())
  @impl true
  def get_monthly_timesheet_history_for_office(
    year,
    month,
    office_id,
    session
  ) when
    is_integer(year) and
    is_integer(month) and
    is_integer(office_id)
  do
    unless Hermes.can_get_timesheet?(session), do: raise DataProtocol.ForbiddenError
    items = Hermes.get_monthly_timesheet_history_for_office(year, month, office_id)
    struct!(DataProtocol.Collection, %{items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get monthly history of timesheet for specified year and month and team
  """
  @spec get_monthly_timesheet_history_for_team(
    year :: integer,
    month :: integer,
    team_id :: integer,
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.HistoryEntry.t())
  @impl true
  def get_monthly_timesheet_history_for_team(
    year,
    month,
    team_id,
    session
  ) when
    is_integer(year) and
    is_integer(month) and
    is_integer(team_id)
  do
    unless Hermes.can_get_timesheet?(session), do: raise DataProtocol.ForbiddenError
    items = Hermes.get_monthly_timesheet_history_for_team(year, month, team_id)
    struct!(DataProtocol.Collection, %{items: items})
  end

end
