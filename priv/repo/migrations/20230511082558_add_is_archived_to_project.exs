defmodule Repo.Migrations.AddIsArchivedToProject do
  use Ecto.Migration

  def change do

    alter table("projects") do
      add :is_archived,     :boolean, default: false
    end

  end
end
