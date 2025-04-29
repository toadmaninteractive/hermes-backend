defmodule WebProtocol.HermesRoleService.Impl do

  @behaviour WebProtocol.HermesRoleService

  # ----------------------------------------------------------------------------

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

  def router() do
    quote do
      match "/api/roles", to: WebProtocol.HermesRoleService.Roles
      match "/api/roles/:id", to: WebProtocol.HermesRoleService.Role
      match "/api/roles/:id/disable/:office_id", to: WebProtocol.HermesRoleService.DisableRole
      match "/api/roles/:id/enable/:office_id", to: WebProtocol.HermesRoleService.EnableRole
    end
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get roles
  """
  @spec get_roles(
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.Role.t())
  @impl true
  def get_roles(
    session
  )
  do
    unless Hermes.can_get_roles?(session), do: raise DataProtocol.ForbiddenError
    struct!(DataProtocol.Collection, %{items: Hermes.get_roles()})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get a role
  """
  @spec get_role(
    id :: integer,
    session :: any()
  ) :: DbProtocol.Role.t()
  @impl true
  def get_role(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_get_role?(session, id), do: raise DataProtocol.ForbiddenError
    Hermes.get_role!(id)
  end

  # ----------------------------------------------------------------------------

  @doc """
  Create a role
  """
  @spec create_role(
    request_content :: WebProtocol.CreateRoleRequest.t(),
    session :: any()
  ) :: DbProtocol.Role.t()
  @impl true
  def create_role(
    request_content,
    session
  ) when
    is_struct(request_content, WebProtocol.CreateRoleRequest)
  do
    unless Hermes.can_create_role?(session), do: raise DataProtocol.ForbiddenError
    role = Hermes.create_role!(Map.from_struct(request_content))
    log_user_action(session, :create, role)
    role
  end

  # ----------------------------------------------------------------------------

  @doc """
  Update a role
  """
  @spec update_role(
    request_content :: WebProtocol.UpdateRoleRequest.t(),
    id :: integer,
    session :: any()
  ) :: DbProtocol.Role.t()
  @impl true
  def update_role(
    request_content,
    id,
    session
  ) when
    is_map(request_content) and
    is_integer(id)
  do
    unless Hermes.can_update_role?(session, id), do: raise DataProtocol.ForbiddenError
    role = Hermes.update_role!(id, request_content)
    log_user_action(session, :update, role)
    role
  end

  # ----------------------------------------------------------------------------

  @doc """
  Delete a role
  """
  @spec delete_role(
    id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def delete_role(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_delete_role?(session, id), do: raise DataProtocol.ForbiddenError
    role = Hermes.get_role!(id)
    :ok = Hermes.delete_role!(id)
    log_user_action(session, :delete, role)
    %DataProtocol.GenericResponse{result: true}
  end

  # ----------------------------------------------------------------------------

  @doc """
  Enable a role for the office
  """
  @spec enable_role_for_office(
    request_content :: CommonProtocol.Empty.t(),
    id :: integer,
    office_id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def enable_role_for_office(
    request_content,
    id,
    office_id,
    session
  ) when
    is_struct(request_content, CommonProtocol.Empty) and
    is_integer(id) and
    is_integer(office_id)
  do
    Hermes.get_role!(id)
    _office = Hermes.get_office!(office_id)
    unless Hermes.can_modify_role_for_office?(session, office_id), do: raise DataProtocol.ForbiddenError
    case Hermes.enable_role_for_office(id, office_id) do
      :ok -> true
      {:error, error} -> raise DataProtocol.BadRequestError, error: error
    end
    # log_user_action(session, :update, item)
    %DataProtocol.GenericResponse{result: true}
  end

  # ----------------------------------------------------------------------------

  @doc """
  Disable a role for the office
  """
  @spec disable_role_for_office(
    request_content :: CommonProtocol.Empty.t(),
    id :: integer,
    office_id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def disable_role_for_office(
    request_content,
    id,
    office_id,
    session
  ) when
    is_struct(request_content, CommonProtocol.Empty) and
    is_integer(id) and
    is_integer(office_id)
  do
    Hermes.get_role!(id)
    _office = Hermes.get_office!(office_id)
    unless Hermes.can_modify_role_for_office?(session, office_id), do: raise DataProtocol.ForbiddenError
    case Hermes.disable_role_for_office(id, office_id) do
      :ok -> true
      {:error, error} -> raise DataProtocol.BadRequestError, error: error
    end
    # log_user_action(session, :update, item)
    %DataProtocol.GenericResponse{result: true}
  end

  # ----------------------------------------------------------------------------
  # internal functions
  #-----------------------------------------------------------------------------

  defp log_user_action(session, action, %DbProtocol.Role{id: id} = object) when is_atom(action) do
    Hermes.log_user_action(session, %{
      operation: action,
      entity: :role,
      entity_id: id,
      properties: %{data: Util.take(object, [:title])}
    })
  end

end
