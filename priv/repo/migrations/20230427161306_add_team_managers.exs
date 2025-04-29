defmodule Repo.Migrations.AddTeamManagers do
  use Ecto.Migration

  @timestamps_opts inserted_at: :created_at

  def change do

    create table("user_team_manager_membership", primary_key: false) do
      add :user_id,         references("users", on_delete: :delete_all), null: false, primary_key: true
      add :team_id,         references("teams", on_delete: :delete_all), null: false, primary_key: true
      timestamps(@timestamps_opts ++ [updated_at: false])
    end

    create unique_index :user_team_manager_membership, [:user_id, :team_id]

    execute("
ALTER TYPE entity_t ADD VALUE 'team_manager_membership'
")

  end
end
