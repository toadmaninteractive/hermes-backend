-include .env
export $(shell sed 's/=.*//' .env)

DESTDIR := server
RELEASE := server
ENV     ?= prod

all: release

init: prerequisites deps
	MIX_ENV=$(ENV) mix do compile, ecto.setup

prerequisites:
	MIX_ENV=$(ENV) mix local.prerequisites

deps:
	MIX_ENV=$(ENV) mix deps.get

clean:
	MIX_ENV=$(ENV) mix clean
	#rm -rf _build $(DESTDIR) deps .elixir_ls

release: deps
	MIX_ENV=$(ENV) mix release $(RELEASE) --force --overwrite

#db-init:
#	#sh etc/db/setup.sh
#	mix ecto.setup

#db-migrate:
#	mix ecto.migrate

install:
	mkdir -p $(DESTDIR)
	cp -Rf _build/$(ENV)/rel/$(RELEASE)/* $(DESTDIR)/

dev: deps
	MIX_ENV=dev iex --sname '$(SYS)-$(FOLDER)' --vm-args rel/vm.args.eex -S mix

.PHONY: all clean deps dev init install prerequisites release
.SILENT:
