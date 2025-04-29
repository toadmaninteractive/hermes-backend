defmodule Repo.Migrations.AddFinanceCodeEtcToProjects do
  use Ecto.Migration

  def change do

    alter table("projects") do
      add :finance_code,      :string, null: false, default: "n/a"
      add :invoiceable,       :boolean, null: false, default: false
      add :task_code,         :string, null: false, default: "project"
    end

    create constraint "projects", "finance_code_can_not_be_empty", check: "trim(finance_code) <> ''"
    create constraint "projects", "task_code_can_not_be_empty", check: "trim(task_code) <> ''"
  end
end
