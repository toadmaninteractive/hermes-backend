#!/bin/bash -x

set -e

cd $(dirname $0)

set -a
. .env
set +a

test $# -lt 1 && echo "Specify database dump file to restrore from" >&2 && exit 2

restore_db() { # db_dump
    dropdb -h 127.0.0.1 -U ${DB_USER} ${DB_NAME}
    createdb -h 127.0.0.1 -U ${DB_USER} -O ${DB_USER} -E utf-8 ${DB_NAME}
    pg_restore -e --dbname=postgresql://${DB_USER}:${DB_PASS}@127.0.0.1:5432/postgres < "$1"
}

restore_db "$1"
