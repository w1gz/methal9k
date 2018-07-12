FROM alpine:3.8

# We need that sweet elixir installation
RUN apk --upgrade --no-cache add bash elixir erlang-mnesia

# setup a default user
RUN adduser -D builder
USER builder

# prepare environment for mix
ENV APP /app
ENV MIX_ENV prod
WORKDIR $APP

# abuse docker cache
ADD mix.exs $APP
ADD mix.lock $APP
RUN mix do local.hex --force, local.rebar --force

# run whatever is in $APP
CMD mix do deps.get --all, release
