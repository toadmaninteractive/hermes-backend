defmodule Repo.Migrations.RenameRollToRole do
  use Ecto.Migration

  def change do

    execute("ALTER INDEX rolls_title_ult_index RENAME TO roles_title_ult_index")
    execute("ALTER INDEX rolls_title_index RENAME TO roles_title_index")
    execute("ALTER INDEX rolls_code_ult_index RENAME TO roles_code_ult_index")
    execute("ALTER INDEX rolls_code_index RENAME TO roles_code_index")

    execute("ALTER SEQUENCE rolls_id_seq RENAME TO roles_id_seq")
    execute("ALTER TABLE ONLY rolls ALTER COLUMN id SET DEFAULT nextval('roles_id_seq'::regclass)")
    execute("SELECT setval('roles_id_seq', (SELECT MAX(id) FROM rolls))")
    execute("ALTER TABLE ONLY rolls RENAME CONSTRAINT rolls_pkey TO roles_pkey")
    execute("ALTER TABLE rolls RENAME TO roles")

    execute("ALTER TABLE users RENAME COLUMN roll_id TO role_id")
    execute("DROP INDEX users_roll_id_index")
    execute("CREATE INDEX users_role_id_index ON users USING btree (role_id)")

    execute("ALTER TABLE ONLY users DROP CONSTRAINT users_roll_id_fkey")
    execute("ALTER TABLE ONLY users ADD CONSTRAINT users_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE SET NULL")

  end
end
