defmodule WebProtocol.HermesReportService.Impl do

  @behaviour WebProtocol.HermesReportService

  # ----------------------------------------------------------------------------

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

  def router() do
    quote do
      match "/api/reports/visma", to: WebProtocol.HermesReportService.VismaReports
      match "/api/reports/visma/omitted/office/:office_id", to: WebProtocol.HermesReportService.VismaReportOmittedEmployees
      match "/api/reports/visma/:report_id", to: WebProtocol.HermesReportService.VismaReport
      match "/api/reports/visma/:report_id/deliver", to: WebProtocol.HermesReportService.VismaReportDelivery
      match "/api/reports/visma/:report_id/download", to: WebProtocol.HermesReportService.VismaReportDownload
      match "/api/reports/visma/:report_id/status", to: WebProtocol.HermesReportService.VismaReportDeliveryStatus
      match "/api/reports/visma/:year/:month/office/:office_id", to: WebProtocol.HermesReportService.VismaReportsForOffice
    end
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get monthly visma reports for particular office
  """
  @spec get_visma_reports_for_office(
    year :: integer,
    month :: integer,
    office_id :: integer,
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.VismaReport.t())
  @impl true
  def get_visma_reports_for_office(
    year,
    month,
    office_id,
    session
  ) when
    is_integer(year) and
    is_integer(month) and
    is_integer(office_id)
  do
    unless Hermes.can_get_visma_report?(session), do: raise DataProtocol.ForbiddenError
    items = Hermes.get_visma_reports(year: year, month: month, office_id: office_id)
    struct!(DataProtocol.Collection, %{items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get visma report
  """
  @spec get_visma_report(
    report_id :: integer,
    session :: any()
  ) :: DbProtocol.VismaReport.t()
  @impl true
  def get_visma_report(
    report_id,
    session
  ) when
    is_integer(report_id)
  do
    unless Hermes.can_get_visma_report?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_visma_report!(report_id)
  end

  # ----------------------------------------------------------------------------

  @doc """
  Create monthly visma report for particular office
  """
  @spec create_visma_report(
    request_content :: WebProtocol.CreateVismaReportRequest.t(),
    session :: any()
  ) :: DbProtocol.VismaReport.t()
  @impl true
  def create_visma_report(
    request_content,
    session
  ) when
    is_struct(request_content, WebProtocol.CreateVismaReportRequest)
  do
    unless Hermes.can_create_visma_report?(session), do: raise DataProtocol.ForbiddenError
    %{year: year, month: month, office_id: office_id} = request_content
    %{omit_ids: omit_ids, omit_uids: omit_uids, pretty: pretty} = request_content
    # NB: take creator from session
    %{user_id: user_id} = session
    fields = Map.from_struct(request_content)
      |> Map.put_new(:created_by, user_id)
    report = Visma.report_for_year_month_office(year, month, office_id, omit_ids: omit_ids, omit_uids: omit_uids, pretty: pretty)
      |> Igor.Json.pack_value({:list, {:custom, VismaProtocol.VismaWeekEntry}})
    fields = fields
      |> Map.put(:report, report)
      |> Map.put(:omit_ids, omit_ids)
      |> Map.put(:omit_uids, omit_uids)
    visma_report = Hermes.create_visma_report!(fields)
    log_user_action(session, :create, visma_report)
    visma_report
  end

  # ----------------------------------------------------------------------------

  @doc """
  Update visma report
  """
  @spec update_visma_report(
    request_content :: WebProtocol.UpdateVismaReportRequest.t(),
    report_id :: integer,
    session :: any()
  ) :: DbProtocol.VismaReport.t()
  @impl true
  def update_visma_report(
    request_content,
    report_id,
    session
  ) when
    is_map(request_content) and
    is_integer(report_id)
  do
    unless Hermes.can_update_visma_report?(session), do: raise DataProtocol.ForbiddenError
    # NB: take updator from session
    %{user_id: user_id} = session
    fields = request_content
      |> Map.put_new(:updated_by, user_id)
    visma_report = Hermes.update_visma_report!(report_id, fields)
    log_user_action(session, :update, visma_report)
    visma_report
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get visma report details
  """
  @spec download_visma_report(
    report_id :: integer,
    session :: any()
  ) :: Igor.Json.json()
  @impl true
  def download_visma_report(
    report_id,
    session
  ) when
    is_integer(report_id)
  do
    unless Hermes.can_get_visma_report?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_visma_report_body!(report_id)
  end


  # ----------------------------------------------------------------------------

  @doc """
  Deliver Visma report to Visma through Junipeer
  """
  @spec deliver_visma_report(
    request_content :: CommonProtocol.Empty.t(),
    report_id :: integer,
    session :: any()
  ) :: DbProtocol.VismaReport.t()
  @impl true
  def deliver_visma_report(
    request_content,
    report_id,
    session
  ) when
    is_struct(request_content, CommonProtocol.Empty) and
    is_integer(report_id)
  do
    unless Hermes.can_create_visma_report?(session), do: raise DataProtocol.ForbiddenError
    report = Hermes.get_visma_report!(report_id)
    body = Hermes.get_visma_report_body!(report_id)
    office = Hermes.get_office!(report.office_id)
    country = office.visma_country
    company_id = office.visma_company_id
    patch = case Visma.submit_visma_report(country, company_id, body) do
      %JunipeerProtocol.JunipeerError{} = error ->
        %{delivery_status: :error, delivery_data: error}
      %JunipeerProtocol.SubmitReportResponse{task_id: task_id} ->
        %{delivery_status: :created, delivery_task_id: task_id}
    end
    Hermes.update_visma_report!(report_id, Map.put_new(patch, :updated_by, session.user_id))
  end

  # ----------------------------------------------------------------------------

  @doc """
  Update Visma report delivery status from Junipeer
  """
  @spec update_visma_report_delivery_status(
    request_content :: CommonProtocol.Empty.t(),
    report_id :: integer,
    session :: any()
  ) :: DbProtocol.VismaReport.t()
  @impl true
  def update_visma_report_delivery_status(
    request_content,
    report_id,
    session
  ) when
    is_struct(request_content, CommonProtocol.Empty) and
    is_integer(report_id)
  do
    unless Hermes.can_create_visma_report?(session), do: raise DataProtocol.ForbiddenError
    %{delivery_task_id: task_id} = Hermes.get_visma_report!(report_id)
    patch = case Visma.get_visma_report_status(task_id) do
      %JunipeerProtocol.JunipeerError{} = error ->
        %{delivery_status: :error, delivery_data: error |> JunipeerProtocol.JunipeerError.to_json!() }
      %JunipeerProtocol.ReportStatusResponse{status: status} = state ->
        patch = %{delivery_status: status, delivery_data: state |> Igor.Json.pack_value({:custom, JunipeerProtocol.ReportStatusResponse})}
        case status do
          :completed -> Map.put(patch, :delivered_at, Util.DateTime.now())
          _ -> patch
        end
    end
    Hermes.update_visma_report!(report_id, Map.put_new(patch, :updated_by, session.user_id))
  end

  @doc """
  Get omitted employees for last Visma report
  """
  @spec get_omitted_employees_for_last_visma_report(
    office_id :: integer,
    session :: any()
  ) :: WebProtocol.OmittedEmployees.t()
  @impl true
  def get_omitted_employees_for_last_visma_report(
    office_id,
    session
  ) when
    is_integer(office_id)
  do
    unless Hermes.can_get_visma_report?(session), do: raise DataProtocol.ForbiddenError
    case Repo.VismaReport.all(office_id: office_id, order_by: {:desc, :updated_at}, limit: 1) do
      [%Repo.VismaReport{omit_ids: omit_ids, omit_uids: omit_uids}] -> %WebProtocol.OmittedEmployees{omit_ids: omit_ids, omit_uids: omit_uids}
      _ -> raise DataProtocol.NotFoundError
    end
  end

  # ----------------------------------------------------------------------------
  # internal functions
  #-----------------------------------------------------------------------------

  defp log_user_action(session, action, %DbProtocol.VismaReport{id: id} = object) when is_atom(action) do
    Hermes.log_user_action(session, %{
      operation: action,
      entity: :report,
      entity_id: id,
      properties: %{data: Util.take(object, [:office_name, :year, :month, :comment])}
    })
  end

end
