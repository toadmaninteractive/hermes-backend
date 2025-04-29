defmodule Repo.Migrations.TuneTimecells do
  use Ecto.Migration

  def change do

    drop index "timecells", [:created_at]
    drop index "timecells", [:updated_at]

    create unique_index "timecells", [:slot_date, :user_id], name: :timecells_date_user_index

    alter table("timecells") do
      add :saved_project_id, :integer
    end

    execute("
CREATE OR REPLACE PROCEDURE ensure_cells(days int) AS $__$
DECLARE
    u record;
    d date;
    now timestamp;
BEGIN
    now := now();
    FOR u IN SELECT id FROM users WHERE NOT is_deleted LOOP
        -- RAISE NOTICE 'Creating cells for user %', u.id;
        d := date_trunc('day', now);
        FOR i IN 1..days LOOP
            INSERT INTO timecells(slot_date, user_id, created_at, updated_at) VALUES(d, u.id, now, now) ON CONFLICT DO NOTHING;
            d := d + 1;
        END LOOP;
    END LOOP;
END
$__$ LANGUAGE PLPGSQL
")

    execute("
CREATE OR REPLACE PROCEDURE ensure_cells(d1 date, d2 date) AS $__$
DECLARE
    u record;
    d DATE;
    now timestamp;
BEGIN
    now := now();
    FOR u IN SELECT id FROM users WHERE NOT is_deleted LOOP
        -- RAISE NOTICE 'Creating cells for user %', u.id;
        FOR d IN SELECT * FROM generate_series(d1, d2, '1 day') LOOP
            INSERT INTO timecells(slot_date, user_id, created_at, updated_at) VALUES(d, u.id, now, now) ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END
$__$ LANGUAGE PLPGSQL
")

#     execute("
# CREATE OR REPLACE PROCEDURE prolong_user_assignment(d date) AS $__$
# DECLARE
#     x record;
# BEGIN
#     WITH cells AS (
#         SELECT c.id cid, u.assigned_to pid
#         FROM timecells c INNER JOIN users u ON u.id = c.user_id
#         WHERE u.assigned_to IS NOT NULL AND NOT u.is_deleted AND c.slot_date = $1 AND (c.time_off IS NULL AND c.project_id IS NULL)
#     )
#     UPDATE timecells
#         SET project_id = cells.pid
#     FROM cells
#     WHERE id = cells.cid;
# END
# $__$ LANGUAGE PLPGSQL
# ")

  end
end
