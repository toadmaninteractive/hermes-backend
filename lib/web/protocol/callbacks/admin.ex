defmodule WebProtocol.HermesAdminService.Impl do

  require WebProtocol.PersonnelAccountOrderBy
  require DataProtocol.OrderDirection
  require WebProtocol.PersonnelAccountRoleOrderBy
  require WebProtocol.PersonnelGroupOrderBy
  require WebProtocol.PersonnelGroupRoleOrderBy

  @behaviour WebProtocol.HermesAdminService

  #-----------------------------------------------------------------------------

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

  def router() do
    quote do
      match "/api/admin/personnel-groups", to: WebProtocol.HermesAdminService.GetPersonnelGroups
      match "/api/admin/personnel-groups/name/:name", to: WebProtocol.HermesAdminService.GetPersonnelGroupByName
      match "/api/admin/personnel-groups/project/:project_id/roles", to: WebProtocol.HermesAdminService.GetPersonnelGroupRolesForProject
      match "/api/admin/personnel-groups/:id", to: WebProtocol.HermesAdminService.GetPersonnelGroup
      match "/api/admin/personnel-groups/:id/roles", to: WebProtocol.HermesAdminService.GetPersonnelGroupRoles
      match "/api/admin/personnel-groups/:id/roles/:project_id", to: WebProtocol.HermesAdminService.AdminPersonnelGroupRole
      match "/api/admin/personnel/project/:project_id/roles", to: WebProtocol.HermesAdminService.GetPersonnelAccountRolesForProject
      match "/api/admin/personnel/username/:username", to: WebProtocol.HermesAdminService.GetPersonnelAccountByUsername
      match "/api/admin/personnel/:id", to: WebProtocol.HermesAdminService.PersonnelAccount
      match "/api/admin/personnel/:id/roles", to: WebProtocol.HermesAdminService.GetPersonnelAccountRoles
      match "/api/admin/personnel/:id/roles/:project_id", to: WebProtocol.HermesAdminService.AdminPersonnelAccountRole
      match "/api/admin/personnels", to: WebProtocol.HermesAdminService.GetPersonnelAccounts
      match "/api/admin/settings", to: WebProtocol.HermesAdminService.AdminSettings
    end
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get single personnel account
  """
  @spec get_personnel_account(
    id :: integer,
    session :: any()
  ) :: DbProtocol.PersonnelAccount.t()
  @impl true
  def get_personnel_account(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_personnel!(id)
  end

  #-----------------------------------------------------------------------------

  @doc """
  Update personnel account
  """
  @spec update_personnel_account(
    request_content :: WebProtocol.UpdatePersonnelAccountRequest.t(),
    id :: integer,
    session :: any()
  ) :: DbProtocol.PersonnelAccount.t()
  @impl true
  def update_personnel_account(
    request_content,
    id,
    session
  ) when
    is_map(request_content) and
    is_integer(id)
  do
    unless Hermes.can_update_personnel?(session, id), do: raise DataProtocol.ForbiddenError
    personnel = Hermes.get_personnel!(id)
    updated_personnel = Hermes.update_personnel!(id, request_content)
    # if updated_personnel != personnel do
    if updated_personnel.role_id != personnel.role_id do
      log_user_action(:user, session, :update, updated_personnel)
    end
    updated_personnel
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get single personnel account by username
  """
  @spec get_personnel_account_by_username(
    username :: String.t(),
    session :: any()
  ) :: DbProtocol.PersonnelAccount.t()
  @impl true
  def get_personnel_account_by_username(
    username,
    session
  ) when
    is_binary(username)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_personnel_by_username!(username)
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get slice of personnel account collection
  """
  @spec get_personnel_accounts(
    needle :: String.t() | nil,
    order_by :: WebProtocol.PersonnelAccountOrderBy.t(),
    order_dir :: DataProtocol.OrderDirection.t(),
    offset :: integer,
    limit :: integer,
    session :: any()
  ) :: DataProtocol.CollectionSlice.t(DbProtocol.PersonnelAccount.t())
  @impl true
  def get_personnel_accounts(
    needle,
    order_by,
    order_dir,
    offset,
    limit,
    session
  ) when
    (is_binary(needle) or needle === nil) and
    WebProtocol.PersonnelAccountOrderBy.is_personnel_account_order_by(order_by) and
    DataProtocol.OrderDirection.is_order_direction(order_dir) and
    is_integer(offset) and
    is_integer(limit)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    needle = needle && "%#{needle}%"
    total = Hermes.count_personnels(name: needle, username: needle)
    items = Hermes.get_personnels(name: needle, username: needle, order_by: [{order_dir, order_by}], offset: offset, limit: limit)
    struct!(DataProtocol.CollectionSlice, %{total: total, items: items})
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get slice of personnel account role collection
  """
  @spec get_personnel_account_roles(
    id :: integer,
    needle :: String.t() | nil,
    order_by :: WebProtocol.PersonnelAccountRoleOrderBy.t(),
    order_dir :: DataProtocol.OrderDirection.t(),
    offset :: integer,
    limit :: integer,
    session :: any()
  ) :: DataProtocol.CollectionSlice.t(DbProtocol.PersonnelAccountRole.t())
  @impl true
  def get_personnel_account_roles(
    id,
    needle,
    order_by,
    order_dir,
    offset,
    limit,
    session
  ) when
    is_integer(id) and
    (is_binary(needle) or needle === nil) and
    WebProtocol.PersonnelAccountRoleOrderBy.is_personnel_account_role_order_by(order_by) and
    DataProtocol.OrderDirection.is_order_direction(order_dir) and
    is_integer(offset) and
    is_integer(limit)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    raise "not yet implemented"
  end

  # ----------------------------------------------------------------------------

  @spec get_personnel_account_roles_for_project(
    project_id :: integer,
    needle :: String.t() | nil,
    order_by :: WebProtocol.PersonnelAccountRoleOrderBy.t(),
    order_dir :: DataProtocol.OrderDirection.t(),
    offset :: integer,
    limit :: integer,
    session :: any()
  ) :: DataProtocol.CollectionSlice.t(DbProtocol.PersonnelAccountRole.t())
  @impl true
  def get_personnel_account_roles_for_project(
    project_id,
    needle,
    order_by,
    order_dir,
    offset,
    limit,
    session
  ) when
    is_integer(project_id) and
    (is_binary(needle) or needle === nil) and
    WebProtocol.PersonnelAccountRoleOrderBy.is_personnel_account_role_order_by(order_by) and
    DataProtocol.OrderDirection.is_order_direction(order_dir) and
    is_integer(offset) and
    is_integer(limit)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    raise "not yet implemented"
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get personnel account role
  """
  @spec get_personnel_account_role(
    id :: integer,
    project_id :: integer,
    session :: any()
  ) :: DbProtocol.PersonnelAccountRole.t()
  @impl true
  def get_personnel_account_role(
    id,
    project_id,
    session
  ) when
    is_integer(id) and
    is_integer(project_id)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    raise "not yet implemented"
  end

  # ----------------------------------------------------------------------------

  @doc """
  Set personnel account role
  """
  @spec set_personnel_account_role(
    request :: WebProtocol.AccessRoleUpdateRequest.t(),
    id :: integer,
    project_id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def set_personnel_account_role(
    request,
    id,
    project_id,
    session
  ) when
    is_struct(request, WebProtocol.AccessRoleUpdateRequest) and
    is_integer(id) and
    is_integer(project_id)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    raise "not yet implemented"
  end

  # ----------------------------------------------------------------------------

  @doc """
  Reset personnel account role
  """
  @spec reset_personnel_account_role(
    id :: integer,
    project_id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def reset_personnel_account_role(
    id,
    project_id,
    session
  ) when
    is_integer(id) and
    is_integer(project_id)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    raise "not yet implemented"
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get single personnel group
  """
  @spec get_personnel_group(
    id :: integer,
    session :: any()
  ) :: DbProtocol.PersonnelGroup.t()
  @impl true
  def get_personnel_group(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_personnel_group!(id)
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get single personnel group by name
  """
  @spec get_personnel_group_by_name(
    name :: String.t(),
    session :: any()
  ) :: DbProtocol.PersonnelGroup.t()
  @impl true
  def get_personnel_group_by_name(
    name,
    session
  ) when
    is_binary(name)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_personnel_group_by_name!(name)
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get slice of personnel group collection
  """
  @spec get_personnel_groups(
    needle :: String.t() | nil,
    order_by :: WebProtocol.PersonnelGroupOrderBy.t(),
    order_dir :: DataProtocol.OrderDirection.t(),
    offset :: integer,
    limit :: integer,
    session :: any()
  ) :: DataProtocol.CollectionSlice.t(DbProtocol.PersonnelGroup.t())
  @impl true
  def get_personnel_groups(
    needle,
    order_by,
    order_dir,
    offset,
    limit,
    session
  ) when
    (is_binary(needle) or needle === nil) and
    WebProtocol.PersonnelGroupOrderBy.is_personnel_group_order_by(order_by) and
    DataProtocol.OrderDirection.is_order_direction(order_dir) and
    is_integer(offset) and
    is_integer(limit)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    needle = needle && "%#{needle}%"
    total = Hermes.count_personnel_groups(name: needle)
    items = Hermes.get_personnel_groups(name: needle, order_by: [{order_dir, order_by}], offset: offset, limit: limit)
    struct!(DataProtocol.CollectionSlice, %{total: total, items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get slice of personnel group role collection
  """
  @spec get_personnel_group_roles(
    id :: integer,
    needle :: String.t() | nil,
    order_by :: WebProtocol.PersonnelGroupRoleOrderBy.t(),
    order_dir :: DataProtocol.OrderDirection.t(),
    offset :: integer,
    limit :: integer,
    session :: any()
  ) :: DataProtocol.CollectionSlice.t(DbProtocol.PersonnelGroupRole.t())
  @impl true
  def get_personnel_group_roles(
    id,
    needle,
    order_by,
    order_dir,
    offset,
    limit,
    session
  ) when
    is_integer(id) and
    (is_binary(needle) or needle === nil) and
    WebProtocol.PersonnelGroupRoleOrderBy.is_personnel_group_role_order_by(order_by) and
    DataProtocol.OrderDirection.is_order_direction(order_dir) and
    is_integer(offset) and
    is_integer(limit)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    raise "not yet implemented"
  end

  # ----------------------------------------------------------------------------

  @spec get_personnel_group_roles_for_project(
    project_id :: integer,
    needle :: String.t() | nil,
    order_by :: WebProtocol.PersonnelGroupRoleOrderBy.t(),
    order_dir :: DataProtocol.OrderDirection.t(),
    offset :: integer,
    limit :: integer,
    session :: any()
  ) :: DataProtocol.CollectionSlice.t(DbProtocol.PersonnelGroupRole.t())
  @impl true
  def get_personnel_group_roles_for_project(
    project_id,
    needle,
    order_by,
    order_dir,
    offset,
    limit,
    session
  ) when
    is_integer(project_id) and
    (is_binary(needle) or needle === nil) and
    WebProtocol.PersonnelGroupRoleOrderBy.is_personnel_group_role_order_by(order_by) and
    DataProtocol.OrderDirection.is_order_direction(order_dir) and
    is_integer(offset) and
    is_integer(limit)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    raise "not yet implemented"
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get personnel group role
  """
  @spec get_personnel_group_role(
    id :: integer,
    project_id :: integer,
    session :: any()
  ) :: DbProtocol.PersonnelGroupRole.t()
  @impl true
  def get_personnel_group_role(
    id,
    project_id,
    session
  ) when
    is_integer(id) and
    is_integer(project_id)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    raise "not yet implemented"
  end

  # ----------------------------------------------------------------------------

  @doc """
  Set personnel group role
  """
  @spec set_personnel_group_role(
    request :: WebProtocol.AccessRoleUpdateRequest.t(),
    id :: integer,
    project_id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def set_personnel_group_role(
    request,
    id,
    project_id,
    session
  ) when
    is_struct(request, WebProtocol.AccessRoleUpdateRequest) and
    is_integer(id) and
    is_integer(project_id)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    raise "not yet implemented"
  end

  # ----------------------------------------------------------------------------

  @doc """
  Reset personnel group role
  """
  @spec reset_personnel_group_role(
    id :: integer,
    project_id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def reset_personnel_group_role(
    id,
    project_id,
    session
  ) when
    is_integer(id) and
    is_integer(project_id)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    raise "not yet implemented"
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get settings
  """
  @spec get_settings(
    session :: any()
  ) :: WebProtocol.Settings.t()
  @impl true
  def get_settings(
    session
  )
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_settings()
  end

  #-----------------------------------------------------------------------------

  @doc """
  Update settings
  """
  @spec update_settings(
    request :: WebProtocol.SettingsUpdateRequest.t(),
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def update_settings(
    request,
    session
  ) when
    is_struct(request, WebProtocol.SettingsUpdateRequest)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    settings = Hermes.update_settings!(Map.from_struct(request))
    log_user_action(:settings, session, :update, settings)
    %DataProtocol.GenericResponse{result: true}
  rescue
    _ -> %DataProtocol.GenericResponse{result: false}
  end

  #-----------------------------------------------------------------------------
  # internal functions
  #-----------------------------------------------------------------------------

  defp log_user_action(:settings, session, action, %{} = object) when is_atom(action) do
    Hermes.log_user_action(session, %{
      operation: action,
      entity: :settings,
      properties: %{data: object}
    })
  end
  defp log_user_action(:user, session, action, %{} = object) when is_atom(action) do
    Hermes.log_user_action(session, %{
      operation: action,
      entity: :user,
      properties: %{
        data: %{role: Util.take(object, [id: :role_id, code: :role_code, title: :role_title])},
        affects: [Util.take(object, [:id, :name, :username])],
      }
    })
  end

end
