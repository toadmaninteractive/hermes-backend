#!/bin/bash -x

set -e

cd $(dirname $0)

set -a
. .env
set +a

TS=`date +%Y-%m-%d_%H-%M-%S`
HEAD=`git ls-remote -qh "$BACKEND_REPO" $BACKEND_BRANCH 2>/dev/null | awk '{print substr($1, 1, 10); nextfile}'`
BUILD=_builds/build-$HEAD

mkdir -p $BUILD

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
        make init all install ENV=$ENV DESTDIR=../server
    )
}

switch_build() {
    rm -f build
    ln -sf $BUILD build
}

build_new
switch_build
