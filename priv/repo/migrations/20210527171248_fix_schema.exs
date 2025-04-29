defmodule Repo.Migrations.FixSchema do
  use Ecto.Migration

  def change do

    alter table("timecells") do
      modify :user_id,      references("users", on_delete: :delete_all)
    end

    drop constraint "offices", "offices_country_id_fkey"
    drop index "offices", [:country_id]
    alter table("offices") do
      modify :country_id,   references("countries", on_delete: :nilify_all)
    end
    create index "offices", [:country_id]

    alter table("timecells") do
      remove :slot_date_iso
    end

  end
end
