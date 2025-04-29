#!/bin/bash -x

set -e

cd $(dirname $0)

set -a
. .env
export MIX_ENV=$ENV
set +a

TS=`date +%Y-%m-%d_%H-%M-%S`
HEAD=`git ls-remote -qh "$BACKEND_REPO" $BACKEND_BRANCH 2>/dev/null | awk '{print substr($1, 1, 10); nextfile}'`
BUILD=_builds/build-$HEAD

mkdir -p $BUILD

backup_db() {
    pg_dump -c -Fc --dbname=postgresql://${DB_USER}:${DB_PASS}@127.0.0.1:5432/${DB_NAME} > build/db-${DB_NAME}-${TS}.dump
    #pg_restore -c --if-exists -e --dbname=postgresql://${DB_USER}:${DB_PASS}@127.0.0.1:5432/${DB_NAME} < build/db-${DB_NAME}-?.dump
}

build_new() {
    rm -rf $BUILD/src
    git clone --depth 1 --single-branch --branch $BACKEND_BRANCH "$BACKEND_REPO" $BUILD/src
    (
        cd $BUILD/src
        if test -s "$HOME/.kiex/scripts/kiex"; then
            . /usr/local/erlang/23.3.4/activate
            . $HOME/.kiex/scripts/kiex
            . $HOME/.kiex/elixirs/elixir-1.12.2.env
        fi
        make all install ENV=$ENV DESTDIR=../server
    )
}

stop_old() {
    ./stop.sh
}

switch_build() {
    rm -f build
    ln -sf $BUILD build
}

start_new() {
    build/server/bin/server daemon
}

build_new
backup_db
stop_old
switch_build
start_new
backup_db
