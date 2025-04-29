defmodule Repo.Migrations.AddDownloadToHistoryOperation do
  use Ecto.Migration

  def change do

    execute("
ALTER TYPE operation_t ADD VALUE 'download'
")

  end
end
