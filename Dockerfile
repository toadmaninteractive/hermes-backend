ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4.3
ARG DEBIAN_VERSION=bullseye-20250908-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# Install build dependencies
RUN apt-get update -y --allow-insecure-repositories \
 && apt-get install -y build-essential git \
 && apt-get clean \
 && rm -f /var/lib/apt/lists/*_*

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force \
 && mix local.rebar --force

# Set build ENV
ENV MIX_ENV="prod"

# Copy files
COPY . .

# Install mix dependencies
RUN chmod +x rel/env.sh.eex \
 && mix deps.get --only $MIX_ENV \
 && mix deps.compile \
 && mix release

# Start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE} AS runner

RUN apt-get update -y --allow-insecure-repositories \
 && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
 && apt-get install -y wget lsb-release gnupg \
 && apt-get clean \
 && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Set correct timezone
RUN echo "Europe/Moscow" > /etc/timezone

# Install Postgres 17 client (psql)
RUN echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
 && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && apt-get update -y --allow-insecure-repositories \
 && apt-get install -y postgresql-client-17 \
 && apt-get clean \
 && rm -f /var/lib/apt/lists/*_*

WORKDIR "/app"
RUN chown nobody /app

# Set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/server ./

VOLUME /app/config.yaml

USER nobody

CMD ["/app/bin/server", "start"]
