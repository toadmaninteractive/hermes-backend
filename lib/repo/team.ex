defmodule Repo.Team do
  use Repo.Schema

  schema "teams" do
    field :rev,             :integer, default: 1
    field :title,           Repo.Types.StringyTrimmed
    many_to_many :users,    Repo.User, unique: true, on_replace: :delete,
                            join_through: "user_team_membership",
                            join_keys: [team_id: :id, user_id: :id]
    belongs_to :owner,      Repo.User, foreign_key: :created_by
    many_to_many :managers, Repo.User, unique: true, on_replace: :delete,
                            join_through: "user_team_manager_membership",
                            join_keys: [team_id: :id, user_id: :id]

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
      |> require_presence(~w(title created_by)a)
      |> check_constraints([
        title: "title_can_not_be_empty",
      ])
      |> check_foreign_constraints([
        created_by: "teams_created_by_fkey",
      ])
      |> unique_constraints([
        title: "teams_title_ult_index",
      ])
  end

  @doc false
  def update_changeset(orig, attrs) do
    import Ecto.Changeset
    orig
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [])
      |> require_presence(~w(title created_by)a)
      |> check_constraints([
        title: "title_can_not_be_empty",
      ])
      |> check_foreign_constraints([
        created_by: "teams_created_by_fkey",
      ])
      |> unique_constraints([
        title: "teams_title_ult_index",
      ])
  end

  # ----------------------------------------------------------------------------

end
