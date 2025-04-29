defmodule Repo.Migrations.AddHiredAtToUser do
  use Ecto.Migration

  def change do

    alter table("users") do
      add :hired_at,        :naive_datetime
    end

  end
end
