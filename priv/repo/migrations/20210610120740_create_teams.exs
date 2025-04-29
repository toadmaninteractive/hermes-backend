defmodule Repo.Migrations.CreateTeams do
  use Ecto.Migration

  @timestamps_opts inserted_at: :created_at

  def change do

    #---------------------------------------------------------------------------
    # teams
    #---------------------------------------------------------------------------

    create table("teams") do
      add :rev,             :integer, default: 1
      add :title,           :string, null: false
      timestamps(@timestamps_opts)
    end

    create constraint "teams", "title_can_not_be_empty", check: "trim(title) <> ''"

    create unique_index "teams", ["(lower(trim(title)))"], name: :teams_title_ult_index

    #---------------------------------------------------------------------------
    # personnel team membership
    #---------------------------------------------------------------------------

    create table(:user_team_membership, primary_key: false) do
      add :user_id,         references("users", on_delete: :delete_all), null: false, primary_key: true
      add :team_id,         references("teams", on_delete: :delete_all), null: false, primary_key: true
    end

    create unique_index :user_team_membership, [:user_id, :team_id]
  end
end
