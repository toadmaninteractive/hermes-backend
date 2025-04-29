defmodule Repo.Group do
  use Repo.Schema

  schema "groups" do
    field :rev,             :integer, default: 1
    field :name,            Repo.Types.StringyTrimmed
    field :description,     Repo.Types.StringyTrimmed
    field :is_superadmin,   :boolean, default: false
    field :is_deleted,      :boolean, default: false
    many_to_many :users,    Repo.User, unique: true, on_replace: :delete,
                            join_through: "user_group_membership",
                            join_keys: [group_id: :id, user_id: :id]
    has_many :offices,      Repo.Office, foreign_key: :group_id, on_delete: :nilify_all

    timestamps()
  end

  # ----------------------------------------------------------------------------
  # api
  # ----------------------------------------------------------------------------

  use Repo.Entity, repo: Repo

  def set_superadmin(name) do
    import Ecto.Query
    name = Util.trimmed_lower(name)
    from(__MODULE__, update: [set: [
      is_superadmin: fragment("(lower(trim(name)) = ?)", ^name)
    ]]) |> Repo.update_all(set: [updated_at: DateTime.utc_now])
    :ok
  end

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
      |> unique_constraints([
        name: "groups_name_index",
        name: "groups_name_ult_index",
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
      |> unique_constraints([
        name: "groups_name_index",
        name: "groups_name_ult_index",
      ])
  end

  # ----------------------------------------------------------------------------

end
