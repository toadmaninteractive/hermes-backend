defmodule Repo.Session do
  use Repo.Schema

  @primary_key false
  schema "sessions" do
    field :id,              :string, primary_key: true
    belongs_to :user,       Repo.User
    field :valid_thru,      :naive_datetime

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
      |> require_presence(~w(id user_id valid_thru)a)
      |> check_constraints([
      ])
      |> check_foreign_constraints([
        user_id: "sessions_user_id_fkey",
      ])
      |> unique_constraints([
        id: "sessions_pkey",
      ])
  end

  @doc false
  def update_changeset(orig, attrs) do
    import Ecto.Changeset
    orig
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [])
      |> require_presence(~w(id user_id valid_thru)a)
      |> check_constraints([
      ])
      |> check_foreign_constraints([
        user_id: "sessions_user_id_fkey",
      ])
      |> unique_constraints([
        id: "sessions_pkey",
      ])
  end

  # ----------------------------------------------------------------------------

end
