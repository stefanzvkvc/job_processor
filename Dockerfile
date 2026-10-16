# Build stage: compile the application into a self-contained release.
FROM elixir:1.19.1-slim AS build

ENV MIX_ENV=prod
WORKDIR /app

# The slim image has no CA certificates, which Mix needs to download Hex.
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force

# Fetch and compile dependencies first, so this layer is cached
# until mix.exs or mix.lock changes.
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod && mix deps.compile

COPY config config
COPY lib lib
RUN mix release

# Runtime stage: only the release and the system libraries it needs.
FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales \
  && rm -rf /var/lib/apt/lists/* \
  && sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8 PORT=4000
WORKDIR /app

RUN useradd --system --create-home app
COPY --from=build --chown=app:app /app/_build/prod/rel/job_processor ./
USER app

EXPOSE 4000
CMD ["bin/job_processor", "start"]
