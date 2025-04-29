defmodule Repo.Migrations.AddVismaReportsTable do
  use Ecto.Migration

  @timestamps_opts inserted_at: :created_at

  def change do

    create table("visma_reports") do

      # add :rev,             :integer, default: 1
      add :office_id,       references("offices", on_delete: :nilify_all)
      add :office_name,     :string, null: false
      add :year,            :integer, null: false
      add :month,           :integer, null: false
      add :comment,         :string, null: false, default: ""
      add :report,          :jsonb, default: "{}"
      add :created_by,      references("users", on_delete: :nilify_all)
      add :created_by_username, :string, null: false
      add :created_by_name, :string, null: false
      add :updated_by,      references("users", on_delete: :nilify_all)
      add :updated_by_username, :string
      add :updated_by_name, :string

      timestamps(@timestamps_opts)
    end

    create index "visma_reports", [:office_id]
    create index "visma_reports", [:year]
    create index "visma_reports", [:year, :month]
    create index "visma_reports", [:office_id, :year, :month]
    create index "visma_reports", [:created_by]
    create index "visma_reports", [:updated_by]

  end
end
