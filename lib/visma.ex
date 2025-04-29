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
    config = Application.fetch_env!(:hermes, :junipeer)
    authorization = "Basic " <> Base.encode64("#{config[:username]}:#{config[:password]}")
    payload = %JunipeerProtocol.ReportEnvelope{
      country: country,
      company_id: company_id,
      data: report
    }
    JunipeerProtocol.JunipeerApi.submit_visma_report(payload, authorization)
  end

  def get_visma_report_status(task_id) when is_binary(task_id) do
    config = Application.fetch_env!(:hermes, :junipeer)
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

  def visma_calendar(2021 = year) when is_integer(year) do
    weeks = [
      {"2021-01-04", "2021-01-10", 1},
      {"2021-01-11", "2021-01-17", 2},
      {"2021-01-18", "2021-01-24", 3},
      {"2021-01-25", "2021-01-31", 4},
      {"2021-02-01", "2021-02-07", 5},
      {"2021-02-08", "2021-02-14", 6},
      {"2021-02-15", "2021-02-21", 7},
      {"2021-02-22", "2021-02-28", 8},
      {"2021-03-01", "2021-03-07", 9},
      {"2021-03-08", "2021-03-14", 10},
      {"2021-03-15", "2021-03-21", 11},
      {"2021-03-22", "2021-03-28", 12},
      {"2021-03-29", "2021-04-04", 13},
      {"2021-04-05", "2021-04-11", 14},
      {"2021-04-12", "2021-04-18", 15},
      {"2021-04-19", "2021-04-25", 16},
      {"2021-04-26", "2021-05-02", 17},
      {"2021-05-03", "2021-05-09", 18},
      {"2021-05-10", "2021-05-16", 19},
      {"2021-05-17", "2021-05-23", 20},
      {"2021-05-24", "2021-05-30", 21},
      {"2021-05-31", "2021-06-06", 22},
      {"2021-06-07", "2021-06-13", 23},
      {"2021-06-14", "2021-06-20", 24},
      {"2021-06-21", "2021-06-27", 25},
      {"2021-06-28", "2021-07-04", 26},
      {"2021-07-05", "2021-07-06", 27},
      {"2021-07-07", "2021-07-11", 28},
      {"2021-07-12", "2021-07-18", 29},
      {"2021-07-19", "2021-07-25", 30},
      {"2021-07-26", "2021-07-31", 31},
      {"2021-08-01", "2021-08-07", 32},
      {"2021-08-08", "2021-08-14", 33},
      {"2021-08-15", "2021-08-21", 34},
      {"2021-08-22", "2021-08-28", 35},
      {"2021-08-29", "2021-08-31", 36},
      {"2021-09-01", "2021-09-07", 37},
      {"2021-09-08", "2021-09-14", 38},
      {"2021-09-15", "2021-09-21", 39},
      {"2021-09-22", "2021-09-28", 40},
      {"2021-09-29", "2021-09-30", 41},
      {"2021-10-01", "2021-10-07", 42},
      {"2021-10-08", "2021-10-14", 43},
      {"2021-10-15", "2021-10-21", 44},
      {"2021-10-22", "2021-10-28", 45},
      {"2021-10-29", "2021-10-31", 46},
      {"2021-11-01", "2021-11-07", 47},
      {"2021-11-08", "2021-11-14", 48},
      {"2021-11-15", "2021-11-21", 49},
      {"2021-11-22", "2021-11-28", 50},
      {"2021-11-29", "2021-11-30", 51},
      {"2021-12-01", "2021-12-07", 52},
      {"2021-12-08", "2021-12-14", 53},
      {"2021-12-15", "2021-12-21", 54},
      {"2021-12-22", "2021-12-28", 55},
      {"2021-12-29", "2021-12-31", 56},
    ]
    weeks
      |> Enum.reduce(%{}, fn {b, e, w}, acc ->
        chunk = Date.range(Date.from_iso8601!(b), Date.from_iso8601!(e))
          |> Enum.map(& {&1, w})
          |> Enum.into(%{})
        Map.merge(acc, chunk)
      end)
  end
  def visma_calendar(2022 = year) when is_integer(year) do
    weeks = [
      {"2022-01-01", "2022-01-02", 1},
      {"2022-01-03", "2022-01-09", 2},
      {"2022-01-10", "2022-01-16", 3},
      {"2022-01-17", "2022-01-23", 4},
      {"2022-01-24", "2022-01-30", 5},
      {"2022-01-31", "2022-01-31", 6},
      {"2022-02-01", "2022-02-06", 7},
      {"2022-02-07", "2022-02-13", 8},
      {"2022-02-14", "2022-02-20", 9},
      {"2022-02-21", "2022-02-27", 10},
      {"2022-02-28", "2022-02-28", 11},
      {"2022-03-01", "2022-03-06", 12},
      {"2022-03-07", "2022-03-13", 13},
      {"2022-03-14", "2022-03-20", 14},
      {"2022-03-21", "2022-03-27", 15},
      {"2022-03-28", "2022-03-31", 16},
      {"2022-04-01", "2022-04-03", 17},
      {"2022-04-04", "2022-04-10", 18},
      {"2022-04-11", "2022-04-17", 19},
      {"2022-04-18", "2022-04-24", 20},
      {"2022-04-25", "2022-04-30", 21},
      {"2022-05-01", "2022-05-01", 22},
      {"2022-05-02", "2022-05-08", 23},
      {"2022-05-09", "2022-05-15", 24},
      {"2022-05-16", "2022-05-22", 25},
      {"2022-05-23", "2022-05-29", 26},
      {"2022-05-30", "2022-05-31", 27},
      {"2022-06-01", "2022-06-05", 28},
      {"2022-06-06", "2022-06-12", 29},
      {"2022-06-13", "2022-06-19", 30},
      {"2022-06-20", "2022-06-26", 31},
      {"2022-06-27", "2022-06-30", 32},
      {"2022-07-01", "2022-07-03", 33},
      {"2022-07-04", "2022-07-10", 34},
      {"2022-07-11", "2022-07-17", 35},
      {"2022-07-18", "2022-07-24", 36},
      {"2022-07-25", "2022-07-31", 37},
      {"2022-08-01", "2022-08-07", 38},
      {"2022-08-08", "2022-08-14", 39},
      {"2022-08-15", "2022-08-21", 40},
      {"2022-08-22", "2022-08-28", 41},
      {"2022-08-29", "2022-08-31", 42},
      {"2022-09-01", "2022-09-04", 43},
      {"2022-09-05", "2022-09-11", 44},
      {"2022-09-12", "2022-09-18", 45},
      {"2022-09-19", "2022-09-25", 46},
      {"2022-09-26", "2022-09-30", 47},
      {"2022-10-01", "2022-10-02", 48},
      {"2022-10-03", "2022-10-09", 49},
      {"2022-10-10", "2022-10-16", 50},
      {"2022-10-17", "2022-10-23", 51},
      {"2022-10-24", "2022-10-30", 52},
      {"2022-10-31", "2022-10-31", 53},
      {"2022-11-01", "2022-11-06", 54},
      {"2022-11-07", "2022-11-13", 55},
      {"2022-11-14", "2022-11-20", 56},
      {"2022-11-21", "2022-11-27", 57},
      {"2022-11-28", "2022-11-30", 58},
      {"2022-12-01", "2022-12-04", 59},
      {"2022-12-05", "2022-12-11", 60},
      {"2022-12-12", "2022-12-18", 61},
      {"2022-12-19", "2022-12-25", 62},
      {"2022-12-26", "2022-12-31", 63},
    ]
    weeks
      |> Enum.reduce(%{}, fn {b, e, w}, acc ->
        chunk = Date.range(Date.from_iso8601!(b), Date.from_iso8601!(e))
          |> Enum.map(& {&1, w})
          |> Enum.into(%{})
        Map.merge(acc, chunk)
      end)
  end
  def visma_calendar(2023 = year) when is_integer(year) do
    weeks = [
      {"2023-01-01", "2023-01-01", 1},
      {"2023-01-02", "2023-01-08", 2},
      {"2023-01-09", "2023-01-15", 3},
      {"2023-01-16", "2023-01-22", 4},
      {"2023-01-23", "2023-01-29", 5},
      {"2023-01-30", "2023-02-05", 6},
      {"2023-02-06", "2023-02-12", 7},
      {"2023-02-13", "2023-02-19", 8},
      {"2023-02-20", "2023-02-26", 9},
      {"2023-02-27", "2023-02-28", 10},
      {"2023-03-01", "2023-03-05", 11},
      {"2023-03-06", "2023-03-12", 12},
      {"2023-03-13", "2023-03-19", 13},
      {"2023-03-20", "2023-03-26", 14},
      {"2023-03-27", "2023-03-31", 15},
      {"2023-04-01", "2023-04-02", 16},
      {"2023-04-03", "2023-04-09", 17},
      {"2023-04-10", "2023-04-16", 18},
      {"2023-04-17", "2023-04-23", 19},
      {"2023-04-24", "2023-04-30", 20},
      {"2023-05-01", "2023-05-07", 21},
      {"2023-05-08", "2023-05-14", 22},
      {"2023-05-15", "2023-05-21", 23},
      {"2023-05-22", "2023-05-28", 24},
      {"2023-05-29", "2023-05-31", 25},
      {"2023-06-01", "2023-06-04", 26},
      {"2023-06-05", "2023-06-11", 27},
      {"2023-06-12", "2023-06-18", 28},
      {"2023-06-19", "2023-06-25", 29},
      {"2023-06-26", "2023-06-30", 30},
      {"2023-07-01", "2023-07-02", 31},
      {"2023-07-03", "2023-07-09", 32},
      {"2023-07-10", "2023-07-16", 33},
      {"2023-07-17", "2023-07-23", 34},
      {"2023-07-24", "2023-07-30", 35},
      {"2023-07-31", "2023-07-31", 36},
      {"2023-08-01", "2023-08-06", 37},
      {"2023-08-07", "2023-08-13", 38},
      {"2023-08-14", "2023-08-20", 39},
      {"2023-08-21", "2023-08-27", 40},
      {"2023-08-28", "2023-08-31", 41},
      {"2023-09-01", "2023-09-03", 42},
      {"2023-09-04", "2023-09-10", 43},
      {"2023-09-11", "2023-09-17", 44},
      {"2023-09-18", "2023-09-24", 45},
      {"2023-09-25", "2023-09-30", 46},
      {"2023-10-01", "2023-10-01", 47},
      {"2023-10-02", "2023-10-08", 48},
      {"2023-10-09", "2023-10-15", 49},
      {"2023-10-16", "2023-10-22", 50},
      {"2023-10-23", "2023-10-29", 51},
      {"2023-10-30", "2023-10-31", 52},
      {"2023-11-01", "2023-11-05", 53},
      {"2023-11-06", "2023-11-12", 54},
      {"2023-11-13", "2023-11-19", 55},
      {"2023-11-20", "2023-11-26", 56},
      {"2023-11-27", "2023-11-30", 57},
      {"2023-12-01", "2023-12-03", 58},
      {"2023-12-04", "2023-12-10", 59},
      {"2023-12-11", "2023-12-17", 60},
      {"2023-12-18", "2023-12-24", 61},
      {"2023-12-25", "2023-12-31", 62},
    ]
    weeks
      |> Enum.reduce(%{}, fn {b, e, w}, acc ->
        chunk = Date.range(Date.from_iso8601!(b), Date.from_iso8601!(e))
          |> Enum.map(& {&1, w})
          |> Enum.into(%{})
        Map.merge(acc, chunk)
      end)
  end
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
