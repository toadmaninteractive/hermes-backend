defmodule Repo.Migrations.RenameDayslots do
  use Ecto.Migration

  def change do

    #---------------------------------------------------------------------------
    # timecell
    #---------------------------------------------------------------------------

    rename table("dayslots"), to: table("timecells")
    create index "timecells", [:created_at]
    create index "timecells", [:updated_at]

  end
end
