defmodule Auth.Bamboo do

  #-----------------------------------------------------------------------------

  @spec get_employee(Keyword.t(), String.t()) :: BambooProtocol.Employee.t()
  def get_employee(config, employee_id) when is_list(config) do
    base_url = config[:base_url]
    company_domain = config[:company_domain]
    authorization = authorization(config[:api_key])
    BambooProtocol.BambooApi.get_employee(base_url, company_domain, employee_id, authorization)
  end

  #-----------------------------------------------------------------------------

  @spec get_employee_directory(Keyword.t()) :: BambooProtocol.EmployeeDirectory.t()
  def get_employee_directory(config) when is_list(config) do
    base_url = config[:base_url]
    company_domain = config[:company_domain]
    authorization = authorization(config[:api_key])
    BambooProtocol.BambooApi.get_employee_directory(base_url, company_domain, authorization)
  end

  #-----------------------------------------------------------------------------

  @spec get_whos_out(Keyword.t(), String.t(), String.t()) :: [BambooProtocol.TimeOffEntry.t()]
  def get_whos_out(config, start_date, end_date) when is_list(config) do
    base_url = config[:base_url]
    company_domain = config[:company_domain]
    authorization = authorization(config[:api_key])
    BambooProtocol.BambooApi.get_whos_out(base_url, company_domain, start_date, end_date, authorization)
  end

  #-----------------------------------------------------------------------------

  @spec get_time_off_requests(Keyword.t(), String.t(), String.t()) :: [BambooProtocol.TimeOffRequest.t()]
  def get_time_off_requests(config, start_date, end_date) when is_list(config) do
    base_url = config[:base_url]
    company_domain = config[:company_domain]
    authorization = authorization(config[:api_key])
    BambooProtocol.BambooApi.get_time_off_requests(base_url, company_domain, start_date, end_date, authorization)
  end

  #-----------------------------------------------------------------------------

  @spec request_custom_report(Keyword.t()) :: BambooProtocol.CustomReport.t()
  def request_custom_report(config) when is_list(config) do
    base_url = config[:base_url]
    company_domain = config[:company_domain]
    authorization = authorization(config[:api_key])
    request = BambooProtocol.CustomReportParams.from_json!(%{"fields" => [
      "id",
      "displayName",
      "firstName",
      "lastName",
      "preferredName",
      "gender",
      "jobTitle",
      "workEmail",
      "department",
      "location",
      "division",
      "photoUploaded",
      "photoUrl",
      "supervisor",
      "supervisorId",
      "supervisorEId",
      "supervisorEmail"
    ]})
    BambooProtocol.BambooApi.request_custom_report(base_url, request, company_domain, authorization)
  end

  #-----------------------------------------------------------------------------
  # internal functions
  #-----------------------------------------------------------------------------

  defp authorization(api_key) do
    "Basic " <> Base.encode64("#{api_key}:x")
  end

  #-----------------------------------------------------------------------------

end
