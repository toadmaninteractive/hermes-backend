defmodule WebProtocol.HermesTaskService.Impl do

  @behaviour WebProtocol.HermesTaskService

  # ----------------------------------------------------------------------------

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

  def router() do
    quote do
      match "/api/tasks/sync_bamboo/monthly/:year/:month", to: WebProtocol.HermesTaskService.TaskSyncBamboo
      match "/api/tasks/sync_ldap", to: WebProtocol.HermesTaskService.TaskSyncLdap
    end
  end

  # ----------------------------------------------------------------------------

  @doc """
  Synchronize with BambooHR
  """
  @spec sync_bamboo(
    request_content :: WebProtocol.SyncBambooTaskRequest.t(),
    year :: integer,
    month :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def sync_bamboo(
    request_content,
    year,
    month,
    session
  ) when
    is_struct(request_content, WebProtocol.SyncBambooTaskRequest)
  do
    %{office_id: office_id, project_id: project_id, team_id: team_id} = request_content
    unless Hermes.can_sync_bamboo?(session, office: office_id, project: project_id, team: team_id), do: raise DataProtocol.ForbiddenError
    :ok = Hermes.sync_timeoffs(year, month)
    %DataProtocol.GenericResponse{result: true}
  end

  # ----------------------------------------------------------------------------

  @doc """
  Synchronize with LDAP
  """
  @spec sync_ldap(
    request_content :: CommonProtocol.Empty.t(),
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def sync_ldap(
    request_content,
    session
  ) when
    is_struct(request_content, CommonProtocol.Empty)
  do
    unless Hermes.can_sync_ldap?(session), do: raise DataProtocol.ForbiddenError
    :ok = Hermes.sync_ldap()
    %DataProtocol.GenericResponse{result: true}
  end

end
