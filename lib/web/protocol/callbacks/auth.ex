defmodule WebProtocol.HermesAuthService.Impl do

  @behaviour WebProtocol.HermesAuthService

  # ----------------------------------------------------------------------------

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

  def router() do
    quote do
      match "/api/auth/personnel/login", to: WebProtocol.HermesAuthService.LoginPersonnel, assigns: %{auth: false}
      match "/api/auth/personnel/logout", to: WebProtocol.HermesAuthService.LogoutPersonnel, assigns: %{auth: false}
      match "/api/auth/personnel/profile", to: WebProtocol.HermesAuthService.GetMyPersonnelProfile
      match "/api/auth/personnel/roles/:project_id/me", to: WebProtocol.HermesAuthService.GetMyRolesForProject
      match "/api/auth/personnel/status", to: WebProtocol.HermesAuthService.GetPersonnelStatus, assigns: %{auth: false}
    end
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get current personnel session status
  """
  @spec get_personnel_status(
    session :: any()
  ) :: WebProtocol.PersonnelStatusResponse.t()
  @impl true
  def get_personnel_status(nil) do
    %WebProtocol.PersonnelStatusResponse{
      logged_in: false
    }
  end
  def get_personnel_status(%{user_id: user_id}) do
    user = Hermes.get_personnel!(user_id)
    %WebProtocol.PersonnelStatusResponse{
      logged_in: true,
      user_id: user.id,
      username: user.username,
      email: user.email
    }
  end

  #-----------------------------------------------------------------------------

  @doc """
  Login personnel
  """
  @spec login_personnel(
    request :: WebProtocol.PersonnelLoginRequest.t(),
    conn :: Plug.Conn.t()
  ) :: {WebProtocol.PersonnelLoginResponse.t(), Plug.Conn.t()}
  @impl true
  def login_personnel(
    request,
    %{assigns: %{session: %{user_id: _}}} = conn # Plug connection
  ) when
    is_struct(request, WebProtocol.PersonnelLoginRequest)
  do
    result = %WebProtocol.PersonnelLoginResponse{
      result: false,
      error: :already_logged_in
    }
    {result, conn}
  end
  def login_personnel(
    %{username: username, password: password} = request,
    conn # Plug connection
  ) when
    is_struct(request, WebProtocol.PersonnelLoginRequest)
  do
    case authenticate(username, password) do
      {:ok, user} ->
        result = %WebProtocol.PersonnelLoginResponse{
          result: true,
          user_id: user.id,
          username: user.username,
          email: user.email
        }
        # create new session
        {:ok, session} = Hermes.create_session(user.id)
        # put new session to cookie
        blob = %{
          key: session.id,
          user_id: result.user_id,
          name: user.name,
          username: username,
          created_at: session.created_at,
          valid_thru: session.valid_thru
        }
        conn = conn
          |> Plug.Conn.put_resp_header("x-session-id", "TODO: x-session-id")
          |> Plug.Conn.put_session(:api, blob)
        log_user_action(blob, :login, blob)
        {result, conn}
      {:error, reason} ->
        result = %WebProtocol.PersonnelLoginResponse{
          result: false,
          error: reason
        }
        {result, conn}
    end
  end

  #-----------------------------------------------------------------------------

  @doc """
  Logout personnel
  """
  @spec logout_personnel(
    request :: CommonProtocol.Empty.t(),
    conn :: Plug.Conn.t()
  ) :: {DataProtocol.GenericResponse.t(), Plug.Conn.t()}
  @impl true
  def logout_personnel(
    request,
    %{assigns: %{session: %{key: id} = session}} = conn # Plug connection
  ) when
    is_struct(request, CommonProtocol.Empty)
  do
    result = %DataProtocol.GenericResponse{
      result: true
    }
    # delete session
    Hermes.delete_session(id)
    # remove session from cookie
    conn = conn
      |> Plug.Conn.delete_session(:api)
    log_user_action(session, :logout, session)
    {result, conn}
  end
  def logout_personnel(
    request,
    %{assigns: %{session: nil}} = conn # Plug connection
  ) when
    is_struct(request, CommonProtocol.Empty)
  do
    result = %DataProtocol.GenericResponse{
      result: false
    }
    {result, conn}
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get current personnel profile
  """
  @spec get_my_personnel_profile(
    session :: any()
  ) :: DbProtocol.PersonnelAccount.t()
  @impl true
  def get_my_personnel_profile(
    nil
  )
  do
    raise DataProtocol.NotFoundError
  end
  def get_my_personnel_profile(
    %{user_id: user_id}
  )
  do
    Hermes.get_personnel!(user_id)
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get current personnel roles for a project
  """
  @spec get_my_roles_for_project(
    project_id :: integer,
    session :: any()
  ) :: DbProtocol.PersonnelAccountRole.t()
  @impl true
  def get_my_roles_for_project(
    project_id,
    nil
  ) when
    is_integer(project_id)
  do
    raise DataProtocol.ForbiddenError
  end
  def get_my_roles_for_project(
    project_id,
    %{user_id: _user_id}
  ) when
    is_integer(project_id)
  do
    raise "not yet implemented"
  end

  #-----------------------------------------------------------------------------
  # internal functions
  #-----------------------------------------------------------------------------

  alias Repo.{User}

  defp authenticate(username, password) when is_binary(username) and is_binary(password) do
    case Auth.Ldap.check(username, password) do
      {:error, _} = error -> error
      {:ok, ldap_user} ->
        {:ok, user} = case User.all(username: ldap_user.uid, limit: 1) do
          [] -> User.insert(Util.take(ldap_user, [username: [:uid], email: [:mail], name: [:cn]]))
          [%{is_blocked: true}] -> {:error, :account_is_blocked}
          [%{is_deleted: true}] -> {:error, :account_is_deleted}
          [user] -> {:ok, user}
        end
        case Hermes.can_login?(user.id) do
          true -> {:ok, user}
          false -> {:error, :forbidden}
        end
    end
  end

  #-----------------------------------------------------------------------------

  defp log_user_action(session, action, %{} = object) when is_atom(action) do
    Hermes.log_user_action(session, %{
      operation: action,
      entity: :auth,
      entity_id: session.user_id,
      # properties: %{data: Util.take(object, [:key])}
      properties: %{data: object}
    })
  end

end
