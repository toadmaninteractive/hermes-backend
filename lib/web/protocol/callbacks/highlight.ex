defmodule WebProtocol.HermesHighlightService.Impl do

  @behaviour WebProtocol.HermesHighlightService

  # ----------------------------------------------------------------------------

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

  def router() do
    quote do
      match "/api/highlights", to: WebProtocol.HermesHighlightService.Highlights
      match "/api/highlights/:id", to: WebProtocol.HermesHighlightService.Highlight
    end
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get highlights
  """
  @spec get_highlights(
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.Highlight.t())
  @impl true
  def get_highlights(
    session
  )
  do
    unless Hermes.can_get_highlights?(session), do: raise DataProtocol.ForbiddenError
    items = Hermes.get_highlights()
    struct!(DataProtocol.Collection, %{items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get a highlight
  """
  @spec get_highlight(
    id :: integer,
    session :: any()
  ) :: DbProtocol.Highlight.t()
  @impl true
  def get_highlight(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_get_highlight?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_highlight!(id)
  end

  # ----------------------------------------------------------------------------

  @doc """
  Create a highlight
  """
  @spec create_highlight(
    request_content :: WebProtocol.CreateHighlightRequest.t(),
    session :: any()
  ) :: DbProtocol.Highlight.t()
  @impl true
  def create_highlight(
    request_content,
    session
  ) when
    is_struct(request_content, WebProtocol.CreateHighlightRequest)
  do
    unless Hermes.can_create_highlight?(session), do: raise DataProtocol.ForbiddenError
    highlight = Hermes.create_highlight!(Map.from_struct(request_content))
    log_user_action(session, :create, highlight)
    highlight
  end

  # ----------------------------------------------------------------------------

  @doc """
  Update a highlight
  """
  @spec update_highlight(
    request_content :: WebProtocol.UpdateHighlightRequest.t(),
    id :: integer,
    session :: any()
  ) :: DbProtocol.Highlight.t()
  @impl true
  def update_highlight(
    request_content,
    id,
    session
  ) when
    is_map(request_content) and
    is_integer(id)
  do
    unless Hermes.can_update_highlight?(session), do: raise DataProtocol.ForbiddenError
    highlight = Hermes.update_highlight!(id, request_content)
    log_user_action(session, :update, highlight)
    highlight
  end

  # ----------------------------------------------------------------------------

  @doc """
  Delete a highlight
  """
  @spec delete_highlight(
    id :: integer,
    session :: any()
  ) :: DataProtocol.GenericResponse.t()
  @impl true
  def delete_highlight(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_delete_highlight?(session), do: raise DataProtocol.ForbiddenError
    highlight = Hermes.get_highlight!(id)
    :ok = Hermes.delete_highlight!(id)
    log_user_action(session, :delete, highlight)
    %DataProtocol.GenericResponse{result: true}
  end

  # ----------------------------------------------------------------------------
  # internal functions
  #-----------------------------------------------------------------------------

  defp log_user_action(session, action, %DbProtocol.Highlight{id: id} = object) when is_atom(action) do
    Hermes.log_user_action(session, %{
      operation: action,
      entity: :highlight,
      entity_id: id,
      properties: %{data: Util.take(object, [:title])}
    })
  end

end
