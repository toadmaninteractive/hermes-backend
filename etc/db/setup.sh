#!/bin/sh

psql -U postgres <<_EOF
CREATE ROLE hermes LOGIN password 'hermes_pass';
CREATE DATABASE hermes ENCODING 'UTF8' OWNER hermes;
CREATE DATABASE hermes_dev ENCODING 'UTF8' OWNER hermes;
_EOF
