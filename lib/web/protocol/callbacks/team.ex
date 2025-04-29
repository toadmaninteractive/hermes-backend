defmodule WebProtocol.HermesTeamService.Impl do

  @behaviour WebProtocol.HermesTeamService

  # ----------------------------------------------------------------------------

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

  def router() do
    quote do
      match "/api/teams", to: WebProtocol.HermesTeamService.Teams
      match "/api/teams/:id", to: WebProtocol.HermesTeamService.Team
      match "/api/teams/:team_id/manager", to: WebProtocol.HermesTeamService.IsCurrentUserTeamManager
      match "/api/teams/:team_id/managers", to: WebProtocol.HermesTeamService.TeamManagers
      match "/api/teams/:team_id/members/:personnel_id", to: WebProtocol.HermesTeamService.TeamMember
      match "/api/teams/:team_id/members/:personnel_id/manager", to: WebProtocol.HermesTeamService.TeamManager
    end
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get teams
  """
  @spec get_teams(
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.Team.t())
  @impl true
  def get_teams(
    session
  )
  do
    unless Hermes.can_get_teams?(session), do: raise DataProtocol.ForbiddenError
    struct!(DataProtocol.Collection, %{items: Hermes.get_teams()})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get a team
  """
  @spec get_team(
    id :: integer,
    session :: any()
  ) :: DbProtocol.Team.t()
  @impl true
  def get_team(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_get_team?(session, id), do: raise DataProtocol.ForbiddenError
    Hermes.get_team!(id)
  end

  # ----------------------------------------------------------------------------

  @doc """
  Create a team
  """
  @spec create_team(
    request_content :: WebProtocol.CreateTeamRequest.t(),
    session :: any()
  ) :: DbProtocol.Team.t()
  @impl true
  def create_team(
    request_content,
    session
  ) when
    is_struct(request_content, WebProtocol.CreateTeamRequest)
  do
    unless Hermes.can_create_team?(session), do: raise DataProtocol.ForbiddenError
    # NB: take creator from session
    %{user_id: user_id} = session
    fields = Map.from_struct(request_content)
      |> Map.put_new(:created_by, user_id)
    team = Hermes.create_team!(fields)
    log_user_action(session, :create, team)
    team
  end

  # ----------------------------------------------------------------------------

  @doc """
  Update a team
  """
  @spec update_team(
    request_content :: WebProtocol.UpdateTeamRequest.t(),
    id :: integer,
    session :: any()
  ) :: DbProtocol.Team.t()
  @impl true
  def update_team(
    request_content,
    id,
    session
  ) when
    is_map(request_content) and
    is_integer(id)
  do
    unless Hermes.can_update_team?(session, id), do: raise DataProtocol.ForbiddenError
    team = Hermes.update_team!(id, request_content)
    log_user_action(session, :update, team)
    team
  end

  # ----------------------------------------------------------------------------

  @doc """
  Delete a team
  """
  @spec delete_team(
    id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def delete_team(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_delete_team?(session, id), do: raise DataProtocol.ForbiddenError
    team = Hermes.get_team!(id)
    :ok = Hermes.delete_team!(id)
    log_user_action(session, :delete, team)
    %DataProtocol.GenericResponse{result: true}
  end

  # ----------------------------------------------------------------------------

  @doc """
  Add user to a team
  """
  @spec add_team_member(
    request_content :: CommonProtocol.Empty.t(),
    team_id :: integer,
    personnel_id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def add_team_member(
    request_content,
    team_id,
    personnel_id,
    session
  ) when
    is_struct(request_content, CommonProtocol.Empty) and
    is_integer(team_id) and
    is_integer(personnel_id)
  do
    Hermes.get_team!(team_id)
    unless Hermes.can_add_team_members?(session, team_id), do: raise DataProtocol.ForbiddenError
    personnel = try do
      Hermes.get_employee!(personnel_id)
    rescue
      DataProtocol.NotFoundError -> raise DataProtocol.BadRequestError, error: :member_not_exists
    end
    Hermes.add_team_member!(team_id, personnel_id)
    log_user_action(session, %{
      operation: :create,
      entity: :team_membership,
      entity_id: team_id,
      entity_param: to_string(personnel_id),
      properties: %{
        affects: [Util.take(personnel, [:id, :name, :username])]
      }
    })
    %DataProtocol.GenericResponse{result: true}
  end

  # ----------------------------------------------------------------------------

  @doc """
  Remove user from a team
  """
  @spec remove_team_member(
    team_id :: integer,
    personnel_id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def remove_team_member(
    team_id,
    personnel_id,
    session
  ) when
    is_integer(team_id) and
    is_integer(personnel_id)
  do
    Hermes.get_team!(team_id)
    unless Hermes.can_remove_team_members?(session, team_id), do: raise DataProtocol.ForbiddenError
    personnel = try do
      Hermes.get_employee!(personnel_id)
    rescue
      DataProtocol.NotFoundError -> raise DataProtocol.BadRequestError, error: :member_not_exists
    end
    Hermes.remove_team_member!(team_id, personnel_id)
    log_user_action(session, %{
      operation: :delete,
      entity: :team_membership,
      entity_id: team_id,
      entity_param: to_string(personnel_id),
      properties: %{
        affects: [Util.take(personnel, [:id, :name, :username])]
      }
    })
    %DataProtocol.GenericResponse{result: true}
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get a list of team managers
  """
  @spec get_team_managers(
    team_id :: integer,
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.PersonnelAccount.t())
  @impl true
  def get_team_managers(
    team_id,
    session
  ) when
    is_integer(team_id)
  do
    unless Hermes.can_get_teams?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_team!(team_id)
    struct!(DataProtocol.Collection, %{items: Hermes.get_team_managers!(team_id)})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Check if current user is a team manager
  """
  @spec is_current_user_team_manager(
    team_id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def is_current_user_team_manager(
    team_id,
    session
  ) when
    is_integer(team_id)
  do
    unless Hermes.can_get_teams?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_team!(team_id)
    Hermes.get_employee!(session.user_id)
    %DataProtocol.GenericResponse{result: Hermes.is_team_manager?(team_id, session.user_id)}
  end

  # ----------------------------------------------------------------------------

  @doc """
  Check if user is a team manager
  """
  @spec is_team_manager(
    team_id :: integer,
    personnel_id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def is_team_manager(
    team_id,
    personnel_id,
    session
  ) when
    is_integer(team_id) and
    is_integer(personnel_id)
  do
    unless Hermes.can_get_teams?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_team!(team_id)
    Hermes.get_employee!(personnel_id)
    %DataProtocol.GenericResponse{result: Hermes.is_team_manager?(team_id, personnel_id)}
  end

  # ----------------------------------------------------------------------------

  @doc """
  Set user as a team manager
  """
  @spec set_team_manager(
    request_content :: CommonProtocol.Empty.t(),
    team_id :: integer,
    personnel_id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def set_team_manager(
    request_content,
    team_id,
    personnel_id,
    session
  ) when
    is_struct(request_content, CommonProtocol.Empty) and
    is_integer(team_id) and
    is_integer(personnel_id)
  do
    team = Hermes.get_team!(team_id)
    unless Hermes.can_set_team_manager?(session, team_id), do: raise DataProtocol.ForbiddenError
    _personnel = try do
      Hermes.get_employee!(personnel_id)
    rescue
      DataProtocol.NotFoundError -> raise DataProtocol.BadRequestError, error: :manager_not_exists
    end
    if team.created_by == personnel_id, do: (raise DataProtocol.BadRequestError, error: :manager_is_owner)
    Hermes.set_team_manager!(team_id, personnel_id)
    # log_user_action(session, %{
    #   operation: :create,
    #   entity: :team_manager_membership,
    #   entity_id: team_id,
    #   entity_param: to_string(personnel_id),
    #   properties: %{
    #     affects: [Util.take(personnel, [:id, :name, :username])]
    #   }
    # })
    %DataProtocol.GenericResponse{result: true}
  end

  # ----------------------------------------------------------------------------

  @doc """
  Unset user as a team manager
  """
  @spec unset_team_manager(
    team_id :: integer,
    personnel_id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def unset_team_manager(
    team_id,
    personnel_id,
    session
  ) when
    is_integer(team_id) and
    is_integer(personnel_id)
  do
    Hermes.get_team!(team_id)
    unless Hermes.can_set_team_manager?(session, team_id), do: raise DataProtocol.ForbiddenError
    _personnel = try do
      Hermes.get_employee!(personnel_id)
    rescue
      DataProtocol.NotFoundError -> raise DataProtocol.BadRequestError, error: :manager_not_exists
    end
    Hermes.unset_team_manager!(team_id, personnel_id)
    # log_user_action(session, %{
    #   operation: :delete,
    #   entity: :team_manager_membership,
    #   entity_id: team_id,
    #   entity_param: to_string(personnel_id),
    #   properties: %{
    #     affects: [Util.take(personnel, [:id, :name, :username])]
    #   }
    # })
    %DataProtocol.GenericResponse{result: true}
  end

  # ----------------------------------------------------------------------------
  # internal functions
  #-----------------------------------------------------------------------------

  defp log_user_action(session, action, %DbProtocol.Team{id: id} = object) when is_atom(action) do
    Hermes.log_user_action(session, %{
      operation: action,
      entity: :team,
      entity_id: id,
      properties: %{data: Util.take(object, [:title])}
    })
  end

  defp log_user_action(session, %{operation: operation} = record) when is_atom(operation) do
    Hermes.log_user_action(session, record)
  end

end
