defmodule Repo.Migrations.AddProjectLinks do
  use Ecto.Migration

  @timestamps_opts inserted_at: :created_at

  def change do

    create table("user_project_membership", primary_key: false) do
      add :user_id,         references("users", on_delete: :delete_all), null: false, primary_key: true
      add :project_id,      references("projects", on_delete: :delete_all), null: false, primary_key: true
      timestamps(@timestamps_opts ++ [updated_at: false])
    end

    create index "user_project_membership", [:user_id]
    create index "user_project_membership", [:project_id]

    execute("
ALTER TYPE entity_t ADD VALUE 'project_membership'
")

  end
end
