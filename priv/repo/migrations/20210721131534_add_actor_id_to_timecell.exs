defmodule Repo.Migrations.AddActorIdToTimecell do
  use Ecto.Migration

  def change do

    alter table("timecells") do
      add :set_by,          :integer
    end
  end
end
