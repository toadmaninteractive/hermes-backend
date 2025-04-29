defmodule Repo.TeamManagerLink do
  use Repo.Schema

  @primary_key false
  schema "user_team_manager_membership" do
    belongs_to :user,       Repo.User, primary_key: true
    belongs_to :team,       Repo.Team, primary_key: true

    timestamps(@timestamps_opts ++ [updated_at: false])
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
      |> require_presence([:user_id, :team_id])
      |> check_constraints([
      ])
      |> unique_constraints([
        member: "user_team_manager_membership_pkey"
      ])
  end

  @doc false
  def update_changeset(_orig, _attrs) do
    raise "not implemented"
  end

  # ----------------------------------------------------------------------------

end
