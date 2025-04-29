defmodule Repo.Migrations.AddIsOfficeManagerToUser do
  use Ecto.Migration

  def change do

    # add is_office_manager to user account
    alter table("users") do
      add :is_office_manager, :boolean, null: false, default: false
    end
    create index "users", [:is_office_manager]
  end
end
