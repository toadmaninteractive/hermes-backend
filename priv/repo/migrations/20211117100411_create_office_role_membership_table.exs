defmodule Repo.Migrations.CreateOfficeRoleMembershipTable do
  use Ecto.Migration

  @timestamps_opts inserted_at: :created_at

  def change do

    create table("office_role_membership", primary_key: false) do
      add :office_id,       references("offices", on_delete: :delete_all), null: false, primary_key: true
      add :role_id,         references("roles", on_delete: :delete_all), null: false, primary_key: true
      timestamps(@timestamps_opts ++ [updated_at: false])
    end

    create index "office_role_membership", [:office_id]
    create index "office_role_membership", [:role_id]

    execute(
      "ALTER TYPE entity_t ADD VALUE 'role_membership'",
      ""
    )

  end
end
