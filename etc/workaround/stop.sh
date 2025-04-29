#!/bin/bash

set -e

ENV=dev

cd $(dirname $0)
server/bin/server stop || true
sleep 1
( pgrep -f /work/hermes/$ENV/backend/server | while read p; do kill -TERM $p; done ) || true
sleep 1
( pgrep -f /work/hermes/$ENV/backend/server | while read p; do kill -KILL $p; done ) || true
