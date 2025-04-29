defmodule Repo.Migrations.AddCommentToTimecell do
  use Ecto.Migration

  def change do

    alter table("timecells") do
      add :comment,         :string
    end
  end
end
