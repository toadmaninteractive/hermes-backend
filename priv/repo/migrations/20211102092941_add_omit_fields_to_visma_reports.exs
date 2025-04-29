defmodule Repo.Migrations.AddOmitFieldsToVismaReports do
  use Ecto.Migration

  def change do

    alter table("visma_reports") do
      add :omit_ids,        :jsonb, default: "[]"
      add :omit_uids,       :jsonb, default: "[]"
    end

  end
end
