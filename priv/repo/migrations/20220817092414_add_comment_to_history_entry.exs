defmodule Repo.Migrations.AddCommentToHistoryEntry do
  use Ecto.Migration

  def change do

    alter table("action_history") do
      add :comment,         :string
    end
  end
end
