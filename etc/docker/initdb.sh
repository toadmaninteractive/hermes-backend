#!/bin/bash

set -e

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" <<-EOSQL
    create role ${DB_USER} login password '${DB_PASS}';
    create database ${DB_NAME} encoding 'utf8' owner ${DB_USER};
EOSQL
