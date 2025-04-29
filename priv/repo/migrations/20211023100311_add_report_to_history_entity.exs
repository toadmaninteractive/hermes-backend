defmodule Repo.Migrations.AddReportToHistoryEntity do
  use Ecto.Migration

  def change do

    execute("
ALTER TYPE entity_t ADD VALUE 'report'
")

  end
end
