::
:: project
::

set SYS=hermes
set FOLDER=dev

set ERLANG_OTP_VERSION=27.0.1
set ELIXIR_VERSION=1.18.4

set FRONTEND_SERVER_NAME=%SYS%-%FOLDER%.yourcompany.com
set FRONTEND_SERVER_CORS=https://%FRONTEND_SERVER_NAME%,http://localhost:4200/

set BACKEND_REPO=https://github.com/toadmaninteractive/%SYS%-backend
set BACKEND_BRANCH=main

set BACKEND_IP=127.0.0.1
set BACKEND_PORT=39101
set BACKEND_SESSION_SECRET=CHANGE_ME
set BACKEND_SESSION_ENCRYPTION_SALT=CHANGE_ME
set BACKEND_SESSION_SIGNING_SALT=CHANGE_ME
set BACKEND_API_KEYS=CHANGE_ME

::
:: database
::

set DB_USER=%SYS%
set DB_PASS=%SYS%_pass
set DB_HOST=127.0.0.1
set DB_PORT=5432
set DB_NAME=%SYS%_dev

::
:: ldap (read from file)
::

for /F "tokens=*" %%i in ('type .env') do set %%i

::
:: misc
::

set BACKEND_ADMIN_GROUP=admins
set BACKEND_XLSX_GENERATOR=http://127.0.0.1:4998/generate

::
:: paths
::

set PATH=C:\Erlang\erl-%ERLANG_OTP_VERSION%\bin;C:\Elixir\%ELIXIR_VERSION%\bin;%PATH%
