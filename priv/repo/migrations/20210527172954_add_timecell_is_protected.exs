defmodule Repo.Migrations.AddTimecellIsProtected do
  use Ecto.Migration

  def change do

    alter table("timecells") do
      add :is_protected,      :boolean, default: false
    end

  end
end
