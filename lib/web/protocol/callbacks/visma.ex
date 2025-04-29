defmodule WebProtocol.HermesVismaService.Impl do

  @behaviour VismaProtocol.HermesVismaService

  # ----------------------------------------------------------------------------

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

  def router() do
    quote do
      match "/api/timeoff/report/monthly/:year/:month/office/:office_id", to: VismaProtocol.HermesVismaService.TimeOffReport, assigns: %{auth_by_api_key: true}
      match "/api/timeoff/report/monthly/:year/:month/office/:office_id/excel", to: VismaProtocol.HermesVismaService.TimeOffExcelReport, assigns: %{auth_by_api_key: true}
      match "/api/visma/report/monthly/by-role/:year/:month/office/:office_id", to: VismaProtocol.HermesVismaService.ReportByRole
      match "/api/visma/report/monthly/:year/:month/office/:office_id", to: VismaProtocol.HermesVismaService.Report, assigns: %{auth_by_api_key: true}
    end
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get Visma monthly report for an office
  """
  @spec get_monthly_report_for_office(
    year :: integer,
    month :: integer,
    office_id :: integer,
    omit_ids :: [integer] | nil,
    omit_uids :: [String.t()] | nil,
    pretty :: boolean | nil,
    api_key :: String.t() | nil
  # ) :: {String.t(), [VismaProtocol.VismaWeekEntry.t()]}
  ) :: {String.t(), binary}
  @impl true
  def get_monthly_report_for_office(
    year,
    month,
    office_id,
    omit_ids,
    omit_uids,
    pretty,
    api_key
  ) when
    is_integer(year) and
    is_integer(month) and
    is_integer(office_id) and
    (is_list(omit_ids) or omit_ids === nil) and
    (is_list(omit_uids) or omit_uids === nil) and
    (is_boolean(pretty) or pretty === nil) and
    (is_binary(api_key) or api_key === nil)
  do
    office = Hermes.get_office!(office_id)
    if api_key !== Util.config(:hermes, [:visma, :offices, office.name, :api_key]), do: raise DataProtocol.ForbiddenError
    body = Visma.report_for_year_month_office(year, month, office_id, omit_ids: omit_ids, omit_uids: omit_uids, pretty: pretty)
      |> Igor.Json.pack_value({:list, {:custom, VismaProtocol.VismaWeekEntry}})
      |> Jason.encode!(pretty: [indent: "    "])
    {"attachment; filename=\"visma-#{year}-#{month}-#{office_id}.json\"", body}
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get Visma monthly report for an office grouped by role
  """
  @spec get_monthly_report_for_office_by_role(
    year :: integer,
    month :: integer,
    office_id :: integer,
    omit_ids :: [integer] | nil,
    omit_uids :: [String.t()] | nil,
    include_ids :: [integer] | nil,
    include_uids :: [String.t()] | nil,
    included_only :: boolean,
    csv :: boolean | nil,
    session :: any()
  ) :: {String.t(), String.t(), binary}
  @impl true
  def get_monthly_report_for_office_by_role(
    year,
    month,
    office_id,
    omit_ids,
    omit_uids,
    include_ids,
    include_uids,
    included_only,
    csv,
    session
  ) when
    is_integer(year) and
    is_integer(month) and
    is_integer(office_id) and
    (is_list(omit_ids) or omit_ids === nil) and
    (is_list(omit_uids) or omit_uids === nil) and
    (is_list(include_ids) or include_ids === nil) and
    (is_list(include_uids) or include_uids === nil) and
    is_boolean(included_only) and
    (is_boolean(csv) or csv === nil)
  do
    unless Hermes.can_get_visma_report?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_office!(office_id)
    report = Visma.report_for_year_month_office_by_role(year, month, office_id, omit_ids: omit_ids, omit_uids: omit_uids, include_ids: include_ids, include_uids: include_uids, included_only: included_only)
    case csv === true do
      false ->
        body = report
          |> Igor.Json.pack_value({:custom, VismaProtocol.VismaRoleReport})
          |> Jason.encode!(pretty: [indent: "    "])
        {"application/json", "attachment; filename=\"visma-#{year}-#{month}-#{office_id}.json\"", body}
      true ->
        project_codes = report.roles
          |> Enum.map(& Map.keys(&1.work_hours_by_project))
          |> List.flatten()
          |> Enum.sort()
          |> Enum.uniq()
        columns = [
          excluded_employees__id: report.excluded_employees |> Enum.map(& &1.id),
          excluded_employees__name: report.excluded_employees |> Enum.map(& &1.name),
          excluded_employees__role_title: report.excluded_employees |> Enum.map(& &1.role_title),
          included_employees__id: report.included_employees |> Enum.map(& &1.id),
          included_employees__name: report.included_employees |> Enum.map(& &1.name),
          included_employees__role_title: report.included_employees |> Enum.map(& &1.role_title),
          month: [report.month],
          year: [report.year],
          office_name: [report.office_name],
          roles__id: report.roles |> Enum.map(& &1.id),
          roles__title: report.roles |> Enum.map(& &1.title),
          roles__visma_code: report.roles |> Enum.map(& &1.visma_code),
          roles__employee_count: report.roles |> Enum.map(& &1.employee_count),
          roles__work_hours: report.roles |> Enum.map(& &1.work_hours),
          roles__absence_hours: report.roles |> Enum.map(& &1.absence_hours),
        ] ++ Enum.map(project_codes, fn project_code -> {"roles__work_hours_#{project_code}", Enum.map(report.roles, & &1.work_hours_by_project[project_code])} end)
        columns = columns |> Enum.map(fn {k, v} -> [k | v] end)
        row_count = columns |> Enum.max_by(& length(&1)) |> length()
        rows = columns
          |> Enum.map(& &1 ++ List.duplicate(nil, row_count - length(&1)))
          |> List.zip()
          |> Enum.map(&Tuple.to_list/1)
        # TODO: use https://github.com/dashbitco/nimble_csv ?
        body = rows
          |> Enum.map(& to_csv(&1))
          |> Enum.join("\n")
        body = :unicode.encoding_to_bom(:utf8) <> body
        {"text/csv", "attachment; filename=\"visma-#{year}-#{month}-#{office_id}.csv\"", body}
    end
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get timeoff monthly report for an office
  """
  @spec get_time_off_monthly_report_for_office(
    year :: integer,
    month :: integer,
    office_id :: integer,
    api_key :: String.t()
  ) :: VismaProtocol.ExcelTimeOffReport.t()
  @impl true
  def get_time_off_monthly_report_for_office(
    year,
    month,
    office_id,
    api_key
  ) when
    is_integer(year) and
    is_integer(month) and
    is_integer(office_id) and
    is_binary(api_key)
  do
    office = Hermes.get_office!(office_id)
    if api_key !== Util.config(:hermes, [:visma, :offices, office.name, :api_key]), do: raise DataProtocol.ForbiddenError
    Visma.report_for_year_month_office_excel(year, month, office_id)
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get timeoff monthly report for an office in XSLX format
  """
  @spec get_time_off_monthly_report_for_office_excel(
    year :: integer,
    month :: integer,
    office_id :: integer,
    omit_ids :: [integer] | nil,
    omit_uids :: [String.t()] | nil,
    api_key :: String.t() | nil,
    session :: any()
  ) :: {String.t(), binary}
  @impl true
  def get_time_off_monthly_report_for_office_excel(
    year,
    month,
    office_id,
    omit_ids,
    omit_uids,
    api_key,
    session
  ) when
    is_integer(year) and
    is_integer(month) and
    is_integer(office_id) and
    (is_list(omit_ids) or omit_ids === nil) and
    (is_list(omit_uids) or omit_uids === nil) and
    (is_binary(api_key) or api_key === nil)
  do
    office = Hermes.get_office!(office_id)
    allowed = cond do
      Hermes.can_login?(session) -> true
      api_key === Util.config(:hermes, [:visma, :offices, office.name, :api_key]) -> true
    end
    unless allowed, do: raise DataProtocol.ForbiddenError
    data = Visma.report_for_year_month_office_excel(year, month, office_id, omit_ids: omit_ids, omit_uids: omit_uids)
      |> Igor.Json.pack_value({:custom, VismaProtocol.ExcelTimeOffReport})
      |> Igor.Json.encode!
    url = Application.get_env(:hermes, :visma)[:xlsx_generator]
    body =  case HTTPoison.post(url, data, [{"content-type", "application/json"}], []) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        raise %Igor.Http.HttpError{status_code: status_code, body: response_body}
      # {:error, %HTTPoison.Error{reason: :econnrefused}} ->
      #   raise %Igor.Http.HttpError{status_code: 502}
      {:error, %HTTPoison.Error{reason: reason}} ->
        raise %Igor.Http.HttpError{status_code: 500, body: reason}
    end
    {"attachment; filename=\"output.xlsx\"", body}
  end

  #-----------------------------------------------------------------------------
  # internal functions
  #-----------------------------------------------------------------------------

  defp to_csv(row) do
    row
      |> Enum.map(& escape_csv(to_string(&1)))
      |> Enum.join(",")
  end

  defp escape_csv(cell) when is_binary(cell) do
    case String.contains?(cell, [",", "\n", "\r", ~S["]]) do
      true -> ~S["] <> String.replace(cell, ~S["], ~S[""]) <> ~S["]
      false -> cell
    end
  end

end
