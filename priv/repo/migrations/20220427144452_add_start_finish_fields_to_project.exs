defmodule Repo.Migrations.AddStartFinishFieldsToProject do
  use Ecto.Migration

  def change do

    alter table("projects") do
      add :started_at,      :naive_datetime
      add :finished_at,     :naive_datetime
    end

  end
end
