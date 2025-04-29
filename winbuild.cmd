@echo off

setlocal enableextensions enableDelayedExpansion

call winenv.cmd
set MIX_ENV=prod

echo === Installing prerequisites...
call mix local.hex --force
if errorlevel 1 pause & exit

call mix local.rebar --force
if errorlevel 1 pause & exit

echo === Fetching dependencies...
call mix deps.get
if errorlevel 1 pause & exit

echo === Generating release...
call mix release server_windows --force --overwrite
if errorlevel 1 pause & exit

endlocal
