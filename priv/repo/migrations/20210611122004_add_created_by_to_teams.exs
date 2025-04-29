defmodule Repo.Migrations.AddCreatedByToTeams do
  use Ecto.Migration

  def change do

    alter table("teams") do
      add :created_by,      references("users", on_delete: :nilify_all)
    end

    create index "teams", [:created_by]
  end
end
