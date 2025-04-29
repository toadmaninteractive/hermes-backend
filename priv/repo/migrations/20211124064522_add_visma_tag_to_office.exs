defmodule Repo.Migrations.AddVismaTagToOffice do
  use Ecto.Migration

  def change do

    alter table("offices") do
      add :visma_tag,       :string
    end

  end
end
