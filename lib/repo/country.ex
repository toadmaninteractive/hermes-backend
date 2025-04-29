defmodule Repo.Country do
  use Repo.Schema

  schema "countries" do
    field :name,            :string
    field :alpha2,          :string
    field :alpha3,          :string
    has_many :offices,      Repo.Office

    timestamps()
  end

  # ----------------------------------------------------------------------------
  # api
  # ----------------------------------------------------------------------------

  use Repo.Entity, repo: Repo

  # ----------------------------------------------------------------------------
  # internal functions
  # ----------------------------------------------------------------------------

  @doc false
  def insert_changeset(attrs) do
    import Ecto.Changeset
    %__MODULE__{}
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [nil, ""])
      |> require_presence(~w(name alpha2 alpha3)a)
      |> check_constraints([
        alpha2: "alpha2_can_not_be_empty",
        alpha3: "alpha3_can_not_be_empty",
        name: "name_can_not_be_empty",
      ])
      |> unique_constraints([
        alpha2: "countries_alpha2_index",
        alpha3: "countries_alpha3_index",
        name: "countries_name_index",
      ])
  end

  @doc false
  def update_changeset(orig, attrs) do
    import Ecto.Changeset
    orig
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [])
      |> require_presence(~w(name alpha2 alpha3)a)
      |> check_constraints([
        alpha2: "alpha2_can_not_be_empty",
        alpha3: "alpha3_can_not_be_empty",
        name: "name_can_not_be_empty",
      ])
      |> unique_constraints([
        alpha2: "countries_alpha2_index",
        alpha3: "countries_alpha3_index",
        name: "countries_name_index",
      ])
  end

  # ----------------------------------------------------------------------------

end
