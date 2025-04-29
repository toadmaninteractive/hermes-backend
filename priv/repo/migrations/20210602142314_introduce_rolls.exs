defmodule Repo.Migrations.IntroduceRolls do
  use Ecto.Migration

  @timestamps_opts inserted_at: :created_at

  def change do

    #---------------------------------------------------------------------------
    # rolls
    #---------------------------------------------------------------------------

    create table("rolls") do
      add :code,            :string, null: false
      add :title,           :string, null: false
      timestamps(@timestamps_opts)
    end

    create constraint "rolls", "code_can_not_be_empty", check: "trim(code) <> ''"
    create constraint "rolls", "title_can_not_be_empty", check: "trim(title) <> ''"

    create unique_index "rolls", [:code]
    create unique_index "rolls", ["(lower(trim(code)))"], name: :rolls_code_ult_index
  end
end
