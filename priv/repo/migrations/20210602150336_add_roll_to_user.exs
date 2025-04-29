defmodule Repo.Migrations.AddRollToUser do
  use Ecto.Migration

  def change do

    # add roll to user account
    alter table("users") do
      add :roll_id,         references("rolls", on_delete: :nilify_all)
    end
    create index "users", [:roll_id]
  end
end
