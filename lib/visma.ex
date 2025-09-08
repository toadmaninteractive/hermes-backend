defmodule Visma do

  alias Repo.{Office, TimeCell}

  # ----------------------------------------------------------------------------
  # api
  # ----------------------------------------------------------------------------

  @spec report(Date.t(), Date.t(), Integer.t(), Keyword.t()) :: [VismaProtocol.VismaWeekEntry.t()]
  def report(date1, date2, office_id, options \\ []) when is_integer(office_id) and is_list(options) do
    omit_ids = options[:omit_ids] || []
    omit_uids = options[:omit_uids] || []
    today = Date.utc_today
    # NB: we use visma-style calendar
    # TODO: learn to generate visma-style calendar
    calendar = visma_calendar(date1.year)

    # for each cell in the range ...
    cs = TimeCell.all_for_date_range_office(date1, date2, office_id)
      |> Enum.filter(& &1.user_id not in omit_ids)
      |> Enum.filter(& &1.personnel_username not in omit_uids)
    cs
      |> Enum.reduce(%{}, fn cell, acc ->
          # group by employee / week number / project id / "finance code"
          uid = cell.user_id
          # pid = cell.project_id
          eid = "#{String.upcase(cell.office_country_alpha2)}#{uid}"
          week = calendar[cell.slot_date |> NaiveDateTime.to_date]
          # week = cell.slot_date |> NaiveDateTime.to_date |> Util.Date.week_number
          day_of_week = Date.day_of_week(cell.slot_date)
          fcode = case cell.project_finance_code || fcode_from_timeoff(cell.time_off) do
            nil when cell.slot_date > today -> 101
            nil -> raise "Visma report inconsistency"
            fcode -> fcode
          end
          # week_key = "#{week}-#{pid}-#{fcode}"
          internal_ref_nr = "#{eid}_#{cell.role}_w#{week}_p#{fcode}"
          acc
            |> Map.put_new(internal_ref_nr, %{
              year: cell.slot_date.year,
              week: week,
              employee_id: cell.role || "???",
              internal_ref_nr: internal_ref_nr,
              summary: %{}
            })
            |> Util.set([internal_ref_nr, :summary, :project_id], to_string(fcode))
            |> Util.set([internal_ref_nr, :summary, :project_task], task_code(cell.project_task_code))
            |> Util.set([internal_ref_nr, :summary, :invoiceable], cell.project_invoiceable || false)
            |> Util.set([internal_ref_nr, :summary, day_of_week(day_of_week)], work_time(cell, day_of_week))
        end)
      # drop keys
      |> Map.values
      # prune empty
      |> Enum.filter(& &1.summary[:mon] || &1.summary[:tue] || &1.summary[:wed] || &1.summary[:thu] || &1.summary[:fri] || &1.summary[:sat] || &1.summary[:sun])
      # sort
      |> Enum.sort(& &1.internal_ref_nr < &2.internal_ref_nr)
      # convert to igor json
      |> Enum.map(fn w ->
          summary = [w.summary]
            |> Enum.map(& Util.to_struct!(&1, VismaProtocol.VismaSummaryEntry))
          w
            |> Map.put(:summary, summary)
            |> Util.to_struct!(VismaProtocol.VismaWeekEntry)
        end)
  end

  @spec report_for_current_day(Integer.t(), Keyword.t()) :: Igor.Json.json()
  def report_for_current_day(office_id, options \\ []) when is_integer(office_id) and is_list(options) do
    today = Date.utc_today
    date1 = today |> Util.Date.to_naive!
    date2 = today |> Util.Date.to_naive!
    report(date1, date2, office_id, options)
  end

  @spec report_for_current_month(Integer.t(), Keyword.t()) :: Igor.Json.json()
  def report_for_current_month(office_id, options \\ []) when is_integer(office_id) and is_list(options) do
    today = Date.utc_today
    date1 = today |> Date.beginning_of_month |> Util.Date.to_naive!
    date2 = today |> Date.end_of_month |> Util.Date.to_naive!
    report(date1, date2, office_id, options)
  end

  @spec report_for_current_year(Integer.t(), Keyword.t()) :: Igor.Json.json()
  def report_for_current_year(office_id, options \\ []) when is_integer(office_id) and is_list(options) do
    today = Date.utc_today
    date1 = NaiveDateTime.new!(today.year, 1, 1, 0, 0, 0)
    date2 = today |> Date.end_of_month |> Util.Date.to_naive!
    report(date1, date2, office_id, options)
  end

  @spec report_for_year_month_office(Integer.t(), Integer.t(), Integer.t(), Keyword.t()) :: [VismaProtocol.VismaWeekEntry.t()]
  def report_for_year_month_office(year, month, office_id, options \\ []) when is_integer(year) and is_integer(month) and is_integer(office_id) and is_list(options) do
    date1 = NaiveDateTime.new!(year, month, 1, 0, 0, 0)
    date2 = date1 |> Date.end_of_month |> Util.Date.to_naive!
    report(date1, date2, office_id, options)
  end

  @spec report_for_year_month_office_by_role(Integer.t(), Integer.t(), Integer.t(), Keyword.t()) :: VismaProtocol.VismaRoleReport.t()
  def report_for_year_month_office_by_role(year, month, office_id, options \\ []) when is_integer(year) and is_integer(month) and is_integer(office_id) and is_list(options) do
    date1 = NaiveDateTime.new!(year, month, 1, 0, 0, 0)
    date2 = date1 |> Date.end_of_month |> Util.Date.to_naive!
    office = Hermes.get_office!(office_id)
    omit_ids = options[:omit_ids] || []
    omit_uids = options[:omit_uids] || []
    include_ids = options[:include_ids] || []
    include_uids = options[:include_uids] || []
    filter_personnel_fn = case options[:included_only] do
      true -> & (&1.user_id in include_ids or &1.personnel_username in include_uids)
      _ -> & not (&1.user_id in omit_ids or &1.personnel_username in omit_uids)
    end
    cells = TimeCell.all_for_date_range_office(date1, date2, office_id)
      |> Enum.filter(& &1.role)
    roles = cells
      |> Enum.filter(filter_personnel_fn)
      |> Enum.group_by(& Util.take(&1, [id: :role_id, title: :role_title, visma_code: :role]))
      |> Enum.map(fn {role, cells} ->
        Map.merge(role, %{
          employee_count: Enum.group_by(cells, & &1.user_id) |> Map.keys() |> length(),
          work_hours: 8 * Enum.count(cells, & &1.project_id),
          work_hours_by_project: Enum.filter(cells, & &1.project_id) |> Enum.group_by(& &1.project_finance_code, fn _ -> 1 end) |> Enum.map(fn {k, v} -> {k, 8 * length(v)} end) |> Enum.into(%{}),
          absence_hours: 8 * Enum.count(cells, & &1.time_off),
        })
      end)
    included_employees = cells
      |> Enum.filter(filter_personnel_fn)
      |> Enum.group_by(& Util.take(&1, [id: :user_id, name: :personnel_name, role_title: :role_title]))
      |> Map.keys()
      |> Enum.sort_by(& &1.id)
    excluded_employees = cells
      |> Enum.reject(filter_personnel_fn)
      |> Enum.group_by(& Util.take(&1, [id: :user_id, name: :personnel_name, role_title: :role_title]))
      |> Map.keys()
      |> Enum.sort_by(& &1.id)
    %VismaProtocol.VismaRoleReport{
      office_id: office_id,
      office_name: office.name,
      year: year,
      month: month,
      included_employees: included_employees,
      excluded_employees: excluded_employees,
      roles: roles,
      total_absence_hours: roles |> Enum.map(& &1.absence_hours) |> Enum.sum(),
      total_work_hours: roles |> Enum.map(& &1.work_hours) |> Enum.sum(),
    }
  end

  @spec report_for_year_month_office_excel(Integer.t(), Integer.t(), Integer.t(), Keyword.t()) :: Igor.Json.json()
  def report_for_year_month_office_excel(year, month, office_id, options \\ []) when is_integer(year) and is_integer(month) and is_integer(office_id) and is_list(options) do
    date1 = NaiveDateTime.new!(year, month, 1, 0, 0, 0)
    date2 = date1 |> Date.end_of_month |> Util.Date.to_naive!
    omit_ids = options[:omit_ids] || []
    omit_uids = options[:omit_uids] || []
    items = TimeCell.all_for_date_range_office(date1, date2, office_id)
      |> Enum.filter(& &1.user_id not in omit_ids)
      |> Enum.filter(& &1.personnel_username not in omit_uids)
      |> Enum.reduce(%{}, fn cell, acc ->
        uid = cell.user_id
        day = Date.diff(cell.slot_date, date1) + 1
        acc
          |> Map.put_new(uid, %{uid: uid, name: cell.personnel_name, time_offs: %{}})
          |> Util.set([uid, :time_offs, day], excel_code_from_timeoff(cell.time_off))
      end)
      |> Map.values
      |> Enum.sort_by(& &1.name)
      |> Enum.map(& Util.to_struct!(&1, VismaProtocol.ExcelEmployeeEntry))
    %VismaProtocol.ExcelTimeOffReport{
      office_name: Office.one!(id: office_id).name,
      date_from: date1,
      date_to: date2,
      items: items
    }
  end

  @spec save_to_file(Igor.Json.json(), String.t()) :: :ok
  def save_to_file(report, filename) when is_binary(filename) do
    text = report
      |> VismaProtocol.VismaWeekEntry.to_json!
      |> Jason.encode!(pretty: true)
    File.write!(filename, text)
  end

  # ----------------------------------------------------------------------------
  # junipeer api
  # ----------------------------------------------------------------------------

  def submit_visma_report(country, company_id, report) when is_binary(country) and is_binary(company_id) do
    config = Util.config!(:hermes, [:junipeer])
    authorization = "Basic " <> Base.encode64("#{config[:username]}:#{config[:password]}")
    payload = %JunipeerProtocol.ReportEnvelope{
      country: country,
      company_id: company_id,
      data: report
    }
    JunipeerProtocol.JunipeerApi.submit_visma_report(payload, authorization)
  end

  def get_visma_report_status(task_id) when is_binary(task_id) do
    config = Util.config!(:hermes, [:junipeer])
    authorization = "Basic " <> Base.encode64("#{config[:username]}:#{config[:password]}")
    JunipeerProtocol.JunipeerApi.get_visma_report_status(task_id, authorization)
  end

  # ----------------------------------------------------------------------------
  # internal functions
  # ----------------------------------------------------------------------------

  defp day_of_week(1), do: :mon
  defp day_of_week(2), do: :tue
  defp day_of_week(3), do: :wed
  defp day_of_week(4), do: :thu
  defp day_of_week(5), do: :fri
  defp day_of_week(6), do: :sat
  defp day_of_week(7), do: :sun

  # TODO: elaborate?
  defp work_time(%{time_off: nil, project_id: nil}, _), do: nil
  defp work_time(_, _), do: 8
  # defp work_time(nil, 1), do: 8
  # defp work_time(nil, 2), do: 8
  # defp work_time(nil, 3), do: 8
  # defp work_time(nil, 4), do: 8
  # defp work_time(nil, 5), do: 8
  # defp work_time(nil, 6), do: nil
  # defp work_time(nil, 7), do: nil
  # defp work_time(_, _), do: 8

  defp task_code(nil), do: ""
  defp task_code(:project), do: "PRO"
  defp task_code(:cont_dev), do: "CDEV"
  defp task_code(:rnd), do: "RND"

  # TODO: FIXME: de-hardcode
  defp fcode_from_timeoff(:vacation), do: 101
  defp fcode_from_timeoff(:paid_vacation), do: 101
  defp fcode_from_timeoff(:unpaid_vacation), do: 100
  defp fcode_from_timeoff(:absence), do: 100
  defp fcode_from_timeoff(:travel), do: 101
  defp fcode_from_timeoff(:vab), do: 101
  defp fcode_from_timeoff(:sick), do: 101
  defp fcode_from_timeoff(:unpaid_sick), do: 100
  defp fcode_from_timeoff(:holiday), do: 101
  defp fcode_from_timeoff(:empty), do: 101
  defp fcode_from_timeoff(:parental_leave), do: 101
  defp fcode_from_timeoff(:maternity_leave), do: 101
  defp fcode_from_timeoff(:time_off), do: 101
  defp fcode_from_timeoff(:temp_leave), do: 101
  # # TODO: FIXME: this clause _should_ never be hit
  # defp fcode_from_timeoff(nil), do: 101
  defp fcode_from_timeoff(nil), do: nil

  # TODO: FIXME: de-hardcode
  defp excel_code_from_timeoff(:vacation), do: 355
  defp excel_code_from_timeoff(:paid_vacation), do: 355
  defp excel_code_from_timeoff(:unpaid_vacation), do: 370
  defp excel_code_from_timeoff(:absence), do: 370
  defp excel_code_from_timeoff(:travel), do: 0
  defp excel_code_from_timeoff(:vab), do: 374
  defp excel_code_from_timeoff(:sick), do: 360
  defp excel_code_from_timeoff(:unpaid_sick), do: 360
  defp excel_code_from_timeoff(:holiday), do: 0
  defp excel_code_from_timeoff(:empty), do: 0
  defp excel_code_from_timeoff(:parental_leave), do: 380
  defp excel_code_from_timeoff(:maternity_leave), do: 380
  defp excel_code_from_timeoff(:time_off), do: 0
  defp excel_code_from_timeoff(:temp_leave), do: 370
  defp excel_code_from_timeoff(nil), do: 0

  def visma_calendar(year) when is_integer(year) do
    weeks(year)
      |> Enum.reduce(%{}, fn {b, e, w}, acc ->
        chunk = Date.range(Date.from_iso8601!(b), Date.from_iso8601!(e))
          |> Enum.map(& {&1, w})
          |> Enum.into(%{})
        Map.merge(acc, chunk)
      end)
  end

  def weeks(year), do: weeks(year, 1, 1)

  defp weeks(year, month, day) do
    dow = Date.from_erl!({year, month, day}) |> Date.day_of_week() |> dow()
    pairs = weeks(year, month, day, dow, 0, {year, 1, 1}, []) |> Enum.reverse()
    week_numbers = Range.new(1, length(pairs)) |> Enum.into([])
    for {{from, to}, wn} <- Enum.zip(pairs, week_numbers) do
      {
        from |> Date.from_erl!() |> Date.to_string(),
        to |> Date.from_erl!() |> Date.to_string(),
        wn
      }
    end
  end

  defp weeks(_year, month, _day, _dow, _dim, _last_date, acc) when month > 12, do: acc
  defp weeks(year, month, day, dow, 0, last_date, acc) do
    dim = :calendar.last_day_of_the_month(year, month)
    weeks(year, month, day, dow, dim, last_date, acc)
  end
  defp weeks(year, month, day, dow, dim, last_date, acc) when day == dim do
    date_pair = {last_date, {year, month, day}}
    last_date = {year, month + 1, 1}
    weeks(year, month + 1, 1, dow_next(dow), 0, last_date, [date_pair | acc])
  end
  defp weeks(year, month, day, dow, dim, last_date, acc) when dow == :sun do
    date_pair = {last_date, {year, month, day}}
    last_date = {year, month, day + 1}
    weeks(year, month, day + 1, dow_next(dow), dim, last_date, [date_pair | acc])
  end
  defp weeks(year, month, day, dow, dim, last_date, acc), do: weeks(year, month, day + 1, dow_next(dow), dim, last_date, acc)

  defp dow(1), do: :mon
  defp dow(2), do: :tue
  defp dow(3), do: :wed
  defp dow(4), do: :thu
  defp dow(5), do: :fri
  defp dow(6), do: :sat
  defp dow(7), do: :sun

  defp dow_next(:mon), do: :tue
  defp dow_next(:tue), do: :wed
  defp dow_next(:wed), do: :thu
  defp dow_next(:thu), do: :fri
  defp dow_next(:fri), do: :sat
  defp dow_next(:sat), do: :sun
  defp dow_next(:sun), do: :mon

  @doc ~S"""
  Returns amount of weeks in the year.

  ## Examples

      iex> visma_calendar_count_weeks 2017
      62
      iex> visma_calendar_count_weeks 2018
      62
      iex> visma_calendar_count_weeks 2019
      61
      iex> visma_calendar_count_weeks 2020
      62
      iex> visma_calendar_count_weeks 2021
      60
      iex> visma_calendar_count_weeks 2022
      62
  """
  def visma_calendar_count_weeks(year) when is_integer(year) do
    vanilla_weeks = Util.Date.week_number(Date.new!(year, 12, 31 - 4))
    additional_weeks = 2..12
      |> Enum.map(& Date.new!(year, &1, 1))
      |> Enum.filter(& &1.day == 1 and Date.day_of_week(&1) != 1)
      |> Enum.count
    vanilla_weeks + additional_weeks
  end

end
