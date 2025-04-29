#!/bin/bash

set -e

cd $(dirname $0)

set -a
. .env
set +a

build/server/bin/server stop || true
sleep 1
( pgrep -f /work/$SYS/$FOLDER/backend/_builds/build- | while read p; do kill -TERM $p; done ) || true
sleep 1
( pgrep -f /work/$SYS/$FOLDER/backend/_builds/build- | while read p; do kill -KILL $p; done ) || true
