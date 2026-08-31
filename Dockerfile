# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian instead of
# Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags

# renovate: datasource=github-tags depName=elixir packageName=elixir-lang/elixir versioning=semver
ARG ELIXIR_VERSION=1.20.3
# renovate: datasource=github-tags depName=erlang packageName=erlang/otp versioning=regex:^(?<major>\d+)\.(?<minor>\d+)(\.(?<patch>\d+))?$ extractVersion=^OTP-(?<version>.*)$
ARG OTP_VERSION=29.0.5
# renovate: datasource=docker depName=ubuntu versioning=ubuntu
ARG UBUNTU_VERSION=resolute-20260811.1

ARG BUILDER_IMAGE=hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-ubuntu-${UBUNTU_VERSION}@sha256:2431278a45d8aa9e019202ee73fc50eed21df9b456c4b72ed09b37550b04069b
ARG RUNNER_IMAGE=ubuntu:${UBUNTU_VERSION}@sha256:2260313b31c8c011cd2eebe728008efac1b3982be73eb71348ea2648d2c0e09b
ARG NODE_IMAGE=node:24.19.0-bookworm-slim@sha256:3638d9a6fe4030bd716be989438248074489337ba3275657f93595428be4fc03

FROM ${NODE_IMAGE} AS node_runtime

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN apt-get update && apt-get install -y git build-essential
RUN apt-get clean && rm -f /var/lib/apt/lists/*_*

COPY --from=node_runtime /usr/local/bin/node /usr/local/bin/node
COPY --from=node_runtime /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

ENV ERL_FLAGS="+JPperf true"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets

RUN npm ci --prefix ./assets

# Compile the release
RUN mix compile

# compile assets
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses6 locales \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/share_secret ./

ARG FLY_IO_RELEASE="true"

ENV FLY_IO_RELEASE=${FLY_IO_RELEASE}

USER nobody

CMD ["/app/bin/server"]
