#!/bin/bash

set -e

ENV=dev

cd $(dirname $0)

build_new() {
  rm -rf src.latest
  git clone --single-branch --branch main https://github.com/toadmaninteractive/hermes-backend src.latest
  (
    cd src.latest
    . /usr/local/erlang/23.3.4/activate
    test -s "$HOME/.kiex/scripts/kiex" && . "$HOME/.kiex/scripts/kiex"
    . $HOME/.kiex/elixirs/elixir-1.11.4.env
    make prerequisites all install ENV=$ENV MIX_ENV=$ENV DESTDIR=../server.latest
  )
}

stop_old() {
  server/bin/server stop || true
  sleep 1
  ( pgrep -f /work/hermes/$ENV/backend/server | while read p; do kill -TERM $p; done ) || true
  sleep 1
  ( pgrep -f /work/hermes/$ENV/backend/server | while read p; do kill -KILL $p; done ) || true
}

switch_build() {
  mv -f src src.prev && mv -f src.latest src && rm -fr src.prev
  mv -f server server.prev && mv -f server.latest server && rm -fr server.prev
  server/bin/server daemon
}

build_new
stop_old
switch_build
