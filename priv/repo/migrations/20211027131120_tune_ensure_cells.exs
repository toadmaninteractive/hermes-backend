defmodule Repo.Migrations.TuneEnsureCells do
  use Ecto.Migration

  def change do

    alter table("users") do
      add :fired_at,        :naive_datetime
    end

    execute("
CREATE OR REPLACE PROCEDURE ensure_cells(days int) AS $__$
DECLARE
    u record;
    d date;
    now timestamp;
BEGIN
    -- create missing cells
    now := now();
    FOR u IN SELECT id FROM users WHERE NOT is_deleted LOOP
        -- RAISE NOTICE 'Creating cells for user %', u.id;
        d := date_trunc('day', now);
        FOR i IN 1..days LOOP
            INSERT INTO timecells(slot_date, user_id, created_at, updated_at) VALUES(d, u.id, now, now) ON CONFLICT DO NOTHING;
            d := d + 1;
        END LOOP;
    END LOOP;
    -- remove fired user cells
    FOR u IN SELECT id, fired_at, date_trunc('month', fired_at + '1 month'::interval) AS fire_date FROM users WHERE fired_at IS NOT NULL LOOP
        -- RAISE NOTICE 'Removing cells for user % since %', u.id, u.fire_date;
        DELETE FROM timecells WHERE user_id = u.id AND slot_date >= u.fire_date;
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
    -- create missing cells
    now := now();
    FOR u IN SELECT id FROM users WHERE NOT is_deleted LOOP
        -- RAISE NOTICE 'Creating cells for user %', u.id;
        FOR d IN SELECT * FROM generate_series(d1, d2, '1 day') LOOP
            INSERT INTO timecells(slot_date, user_id, created_at, updated_at) VALUES(d, u.id, now, now) ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
    -- remove fired user cells
    FOR u IN SELECT id, fired_at, date_trunc('month', fired_at + '1 month'::interval) AS fire_date FROM users WHERE fired_at IS NOT NULL LOOP
        -- RAISE NOTICE 'Removing cells for user % since %', u.id, u.fire_date;
        DELETE FROM timecells WHERE user_id = u.id AND slot_date >= u.fire_date;
    END LOOP;
END
$__$ LANGUAGE PLPGSQL
")

  end
end
