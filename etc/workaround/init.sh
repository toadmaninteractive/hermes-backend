#!/bin/bash

set -e

ENV=dev

cd $(dirname $0)
mkdir server
rm -rf src
git clone --single-branch --branch main https://github.com/toadmaninteractive/hermes-backend src
. /usr/local/erlang/23.3.4/activate
[[ -s "$HOME/.kiex/scripts/kiex" ]] && source "$HOME/.kiex/scripts/kiex"
source $HOME/.kiex/elixirs/elixir-1.11.4.env
make -C src prerequisites init install ENV=$ENV MIX_ENV=$ENV DESTDIR=../server
server/bin/server daemon
