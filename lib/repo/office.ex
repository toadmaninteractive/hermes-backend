defmodule Repo.Office do
  use Repo.Schema

  schema "offices" do
    field :rev,             :integer, default: 1
    field :name,            Repo.Types.StringyTrimmed
    field :city,            Repo.Types.StringyTrimmed
    field :address,         Repo.Types.StringyTrimmed
    field :postal_code,     Repo.Types.StringyTrimmed
    belongs_to :group,      Repo.Group
    belongs_to :country,    Repo.Country
    has_many :users,        Repo.User, on_delete: :nilify_all
    has_many :roles,        Repo.OfficeRoleLink, on_replace: :delete
    field :visma_country,   Repo.Types.StringyTrimmedLower
    field :visma_company_id, Repo.Types.StringyTrimmedLower

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
      |> require_presence(~w(name)a)
      |> check_constraints([
        name: "name_can_not_be_empty",
      ])
      |> check_foreign_constraints([
        country_id: "offices_country_id_fkey",
        group_id: "offices_group_id_fkey",
      ])
      |> unique_constraints([
        name: "offices_name_index",
        name: "offices_name_ult_index",
      ])
  end

  @doc false
  def update_changeset(orig, attrs) do
    import Ecto.Changeset
    orig
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [])
      |> require_presence(~w(name)a)
      |> check_constraints([
        name: "name_can_not_be_empty",
      ])
      |> check_foreign_constraints([
        country_id: "offices_country_id_fkey",
        group_id: "offices_group_id_fkey",
      ])
      |> unique_constraints([
        name: "offices_name_index",
        name: "offices_name_ult_index",
      ])
  end

  # ----------------------------------------------------------------------------

end
