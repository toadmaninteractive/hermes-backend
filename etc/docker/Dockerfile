FROM bitwalker/alpine-elixir-phoenix:1.12 AS ex-builder

RUN \
    apk --update --no-cache add git

ARG \
    SYS ENV FOLDER BACKEND_REPO BACKEND_BRANCH

ENV \
    SYS=$SYS \
    FOLDER=$FOLDER \
    BACKEND_REPO=$BACKEND_REPO \
    BACKEND_BRANCH=$BACKEND_BRANCH \
    MIX_ENV=$ENV

RUN git clone --depth 1 --single-branch --branch $BACKEND_BRANCH "${BACKEND_REPO}" src
RUN cd src && MIX_ENV=$MIX_ENV mix do deps.get, deps.compile, release --overwrite server

FROM alpine

RUN \
    apk --update --no-cache add openssl libcrypto1.1 ncurses-libs libstdc++

WORKDIR /app

ARG \
    ENV BACKEND_PORT

ENV \
    MIX_ENV=$ENV \
    BACKEND_PORT=$BACKEND_PORT

EXPOSE $BACKEND_PORT

COPY --from=ex-builder /opt/app/src/_build/$MIX_ENV/rel/server /app

CMD ["/app/bin/server", "start"]
