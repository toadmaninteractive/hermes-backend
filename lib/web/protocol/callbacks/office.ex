defmodule WebProtocol.HermesOfficeService.Impl do

  @behaviour WebProtocol.HermesOfficeService

  # ----------------------------------------------------------------------------

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

  def router() do
    quote do
      match "/api/offices", to: WebProtocol.HermesOfficeService.Offices
      match "/api/offices/:id", to: WebProtocol.HermesOfficeService.Office
    end
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get offices
  """
  @spec get_offices(
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.Office.t())
  @impl true
  def get_offices(
    session
  )
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    struct!(DataProtocol.Collection, %{items: Hermes.get_offices()})
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get an office
  """
  @spec get_office(
    id :: integer,
    session :: any()
  ) :: DbProtocol.Office.t()
  @impl true
  def get_office(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_office!(id)
  end

  #-----------------------------------------------------------------------------

  @doc """
  Create an office
  """
  @spec create_office(
    request_content :: WebProtocol.CreateOfficeRequest.t(),
    session :: any()
  ) :: DbProtocol.Office.t()
  @impl true
  def create_office(
    request_content,
    session
  ) when
    is_struct(request_content, WebProtocol.CreateOfficeRequest)
  do
    unless Hermes.can_create_office?(session), do: raise DataProtocol.ForbiddenError
    office = Hermes.create_office!(Map.from_struct(request_content))
    log_user_action(session, :create, office)
    office
  end

  #-----------------------------------------------------------------------------

  @doc """
  Update an office
  """
  @spec update_office(
    request_content :: WebProtocol.UpdateOfficeRequest.t(),
    id :: integer,
    session :: any()
  ) :: DbProtocol.Office.t()
  @impl true
  def update_office(
    request_content,
    id,
    session
  ) when
    is_map(request_content) and
    is_integer(id)
  do
    unless Hermes.can_update_office?(session, id), do: raise DataProtocol.ForbiddenError
    office = Hermes.update_office!(id, request_content)
    log_user_action(session, :update, office)
    office
  end

  #-----------------------------------------------------------------------------

  @doc """
  Delete an office
  """
  @spec delete_office(
    id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def delete_office(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_delete_office?(session, id), do: raise DataProtocol.ForbiddenError
    office = Hermes.get_office!(id)
    :ok = Hermes.delete_office!(id)
    log_user_action(session, :delete, office)
    %DataProtocol.GenericResponse{result: true}
  end

  #-----------------------------------------------------------------------------
  # internal functions
  #-----------------------------------------------------------------------------

  defp log_user_action(session, action, %DbProtocol.Office{id: id} = object) when is_atom(action) do
    Hermes.log_user_action(session, %{
      operation: action,
      entity: :office,
      entity_id: id,
      properties: %{data: Util.take(object, [:name])}
    })
  end

end
