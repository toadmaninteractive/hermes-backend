defmodule Repo.Migrations.AddAbsenceToHistoryOperation do
  use Ecto.Migration

  def change do

    execute("
ALTER TYPE operation_t ADD VALUE 'absence'
")

  end
end
