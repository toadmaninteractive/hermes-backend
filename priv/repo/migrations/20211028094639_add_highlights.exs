defmodule Repo.Migrations.AddHighlights do
  use Ecto.Migration

  @timestamps_opts inserted_at: :created_at

  def change do

    create table("highlights") do
      add :rev,             :integer, default: 1
      add :code,            :string, null: false
      add :title,           :string, null: false
      timestamps(@timestamps_opts)
    end

    create constraint "highlights", "code_can_not_be_empty", check: "trim(code) <> ''"
    create constraint "highlights", "title_can_not_be_empty", check: "trim(title) <> ''"

    create unique_index "highlights", [:code]
    create unique_index "highlights", ["(lower(trim(code)))"], name: :highlights_code_ult_index
    create unique_index "highlights", [:title]
    create unique_index "highlights", ["(lower(trim(title)))"], name: :highlights_title_ult_index

    create table("user_project_highlight_membership", primary_key: false) do
      add :user_id,         references("users", on_delete: :delete_all), null: false, primary_key: true
      add :project_id,      references("projects", on_delete: :delete_all), null: false, primary_key: true
      add :highlight_id,    references("highlights", on_delete: :delete_all), null: false, primary_key: true
      timestamps(@timestamps_opts ++ [updated_at: false])
    end

    create unique_index "user_project_highlight_membership", [:user_id, :project_id, :highlight_id]
    create index "user_project_highlight_membership", [:user_id]
    create index "user_project_highlight_membership", [:project_id]
    create index "user_project_highlight_membership", [:user_id, :project_id]

    execute("
ALTER TYPE entity_t ADD VALUE 'highlight'
")
    execute("
ALTER TYPE entity_t ADD VALUE 'project_highlight_membership'
")

  end
end
