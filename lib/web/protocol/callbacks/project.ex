defmodule WebProtocol.HermesProjectService.Impl do

  @behaviour WebProtocol.HermesProjectService

  # ----------------------------------------------------------------------------

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

  def router() do
    quote do
      match "/api/projects", to: WebProtocol.HermesProjectService.Projects
      match "/api/projects/:id", to: WebProtocol.HermesProjectService.Project
    end
  end

  #-----------------------------------------------------------------------------

  @spec get_projects(
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.Project.t())
  @impl true
  def get_projects(
    session
  )
  do
    unless Hermes.can_get_projects?(session), do: raise DataProtocol.ForbiddenError
    struct!(DataProtocol.Collection, %{items: Hermes.get_projects()})
  end

  #-----------------------------------------------------------------------------

  @spec get_project(
    id :: integer,
    session :: any()
  ) :: DbProtocol.Project.t()
  @impl true
  def get_project(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_get_project?(session, id), do: raise DataProtocol.ForbiddenError
    Hermes.get_project!(id)
  end

  #-----------------------------------------------------------------------------

  @spec create_project(
    request_content :: WebProtocol.CreateProjectRequest.t(),
    session :: any()
  ) :: DbProtocol.Project.t()
  @impl true
  def create_project(
    request_content,
    session
  ) when
    is_struct(request_content, WebProtocol.CreateProjectRequest)
  do
    unless Hermes.can_create_project?(session), do: raise DataProtocol.ForbiddenError
    project = Hermes.create_project!(Map.from_struct(request_content))
    log_user_action(session, :create, project)
    project
  end

  #-----------------------------------------------------------------------------

  @spec update_project(
    request_content :: WebProtocol.UpdateProjectRequest.t(),
    id :: integer,
    session :: any()
  ) :: DbProtocol.Project.t()
  @impl true
  def update_project(
    request_content,
    id,
    session
  ) when
    is_map(request_content) and
    is_integer(id)
  do
    request_content = case Hermes.can_update_project?(session, id) do
      false -> raise DataProtocol.ForbiddenError
      true -> request_content
      :only_supervisor_id -> request_content |> Map.take([:supervisor_id])
    end
    project = Hermes.update_project!(id, request_content)
    log_user_action(session, :update, project)
    project
  end

  #-----------------------------------------------------------------------------

  @spec delete_project(
    id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def delete_project(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_delete_project?(session, id), do: raise DataProtocol.ForbiddenError
    project = Hermes.get_project!(id)
    :ok = Hermes.delete_project!(id)
    log_user_action(session, :delete, project)
    %DataProtocol.GenericResponse{result: true}
  end

  #-----------------------------------------------------------------------------
  # internal functions
  #-----------------------------------------------------------------------------

  defp log_user_action(session, action, %DbProtocol.Project{id: id} = object) when is_atom(action) do
    Hermes.log_user_action(session, %{
      operation: action,
      entity: :project,
      entity_id: id,
      properties: %{data: Util.take(object, [:title])}
    })
  end

end
