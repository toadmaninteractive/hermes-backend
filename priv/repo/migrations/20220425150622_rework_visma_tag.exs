defmodule Repo.Migrations.ReworkVismaTag do
  use Ecto.Migration

  def change do

    alter table("offices") do
      add :visma_country,   :string
      add :visma_company_id, :string
      remove :visma_tag,    :string
    end

  end
end
