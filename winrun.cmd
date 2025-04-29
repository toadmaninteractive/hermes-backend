@echo off

setlocal enableextensions enableDelayedExpansion

call winenv.cmd

call mix deps.get
call mix do compile, ecto.setup
call iex -S mix

endlocal
