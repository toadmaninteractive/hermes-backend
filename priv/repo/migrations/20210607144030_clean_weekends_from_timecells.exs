defmodule Repo.Migrations.CleanWeekendsFromTimecells do
  use Ecto.Migration

  def change do

    Repo.query!("update timecells set time_off = null where time_off = 'weekend'")
  end
end
