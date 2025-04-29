#!/bin/bash

set -e

cd $(dirname $0)

set -a
. .env
set +a

./stop.sh
build/server/bin/server daemon
