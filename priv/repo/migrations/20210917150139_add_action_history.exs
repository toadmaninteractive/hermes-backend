defmodule Repo.Migrations.AddActionHistory do
  use Ecto.Migration

  @timestamps_opts inserted_at: :created_at, updated_at: false

  def change do

    execute("
CREATE TYPE actor_t AS ENUM (
    'user',
    'robot',
    'anonymous'
)
")

    execute("
CREATE TYPE entity_t AS ENUM (
    'auth',
    'session',
    'settings',
    'user',
    'group',
    'group_membership',
    'country',
    'role',
    'office',
    'project',
    'team',
    'team_membership',
    'timecell'
)
")

    execute("
CREATE TYPE operation_t AS ENUM (
    'create',
    'read',
    'update',
    'delete',
    'undelete',
    'block',
    'unblock',
    'login',
    'logout',
    'allocate',
    'deallocate',
    'protect',
    'unprotect'
)
")

    create table("action_history") do

      add :actor,           :actor_t, null: false
      add :actor_id,        :bigint
      add :actor_name,      :string
      add :actor_username,  :string
      add :entity,          :entity_t, null: false
      add :entity_id,       :bigint
      add :entity_param,    :string
      add :operation,       :operation_t, null: false
      add :is_bulk,         :boolean, default: false
      add :properties,      :jsonb, default: "{}"
      add :result,          :boolean, default: false

      timestamps(@timestamps_opts)
    end

    # create constraint "action_history", "actor_can_not_be_empty", check: "trim(actor) <> ''"
    # create constraint "action_history", "entity_can_not_be_empty", check: "trim(entity) <> ''"
    # create constraint "action_history", "operation_can_not_be_empty", check: "trim(operation) <> ''"

  end
end
