#!/bin/bash

set -e

cd $(dirname $0)

set -a
. .env
set +a

psql -h 127.0.0.1 -U $DB_USER -W $DB_NAME
