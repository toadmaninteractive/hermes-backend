#!/bin/bash -x

set -e

cd $(dirname $0)

set -a
. .env
set +a

test $# -lt 1 && echo "Specify rollback build directory" >&2 && exit 2

TS=`date +%Y-%m-%d_%H-%M-%S`
BUILD="$1"

backup() {
    pg_dump -c -Fc --dbname=postgresql://${DB_USER}:${DB_PASS}@127.0.0.1:5432/${DB_NAME} > build/db-${DB_NAME}-${TS}.dump
    cp -f build build.$TS
}

restore_db() {
    dropdb -h 127.0.0.1 -U ${DB_USER} ${DB_NAME}
    createdb -h 127.0.0.1 -U ${DB_USER} -O ${DB_USER} -E utf-8 ${DB_NAME}
    local DB_DUMP=`ls -r1 $BUILD/*.dump | head -n 1`
    pg_restore -e --dbname=postgresql://${DB_USER}:${DB_PASS}@127.0.0.1:5432/postgres < "$DB_DUMP"
}

switch_build() {
    rm -f build
    ln -sf $BUILD build
}

start_new() {
    build/server/bin/server daemon
}

./stop.sh
#backup
restore_db
switch_build
start_new

exit 0
