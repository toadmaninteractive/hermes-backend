defmodule Repo.Migrations.AddUserAssignedTo do
  use Ecto.Migration

  def change do

    # link personnel user accounts to projects
    alter table("users") do
      add :assigned_to,     references("projects", on_delete: :nilify_all)
    end
    create index "users", [:assigned_to]

  end
end
