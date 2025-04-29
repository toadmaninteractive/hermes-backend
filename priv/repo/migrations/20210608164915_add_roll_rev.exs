defmodule Repo.Migrations.AddRollRev do
  use Ecto.Migration

  def change do

    alter table("rolls") do
      add :rev,             :integer, default: 1
    end

    create unique_index "rolls", [:title]
    create unique_index "rolls", ["(lower(trim(title)))"], name: :rolls_title_ult_index

  end
end
