defmodule WebProtocol.HermesDirectoryService.Impl do

  @behaviour WebProtocol.HermesDirectoryService

  # ----------------------------------------------------------------------------

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

  def router() do
    quote do
      match "/api/directory/countries", to: WebProtocol.HermesDirectoryService.Countries
      match "/api/directory/countries/:id", to: WebProtocol.HermesDirectoryService.Country
    end
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get all countries
  """
  @spec get_countries(
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.Country.t())
  @impl true
  def get_countries(
    session
  )
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    struct!(DataProtocol.Collection, %{items: Hermes.get_countries()})
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get country
  """
  @spec get_country(
    id :: integer,
    session :: any()
  ) :: DbProtocol.Country.t()
  @impl true
  def get_country(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_country!(id)
  end

  #-----------------------------------------------------------------------------
  # internal functions
  #-----------------------------------------------------------------------------

end
