defmodule Repo.Migrations.ProjectAddColor do
  use Ecto.Migration

  def change do

    alter table("projects") do
      add :color,           :string
    end

  end
end
