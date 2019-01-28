# Motivation

This is a good exercise for learning more about Elixir, Erlang and
OTP. Furthermore, Hal greatly benefits from the features provided by OTP:
GenServer, Supervisor or even Hot code loading.


# Installation

## Bare metal

Everything in methal9k is handle by [Mix](https://hexdocs.pm/mix/Mix.html) and the project's
`Makefile`. To run the bot, simply execute: `make run`.

## Docker for local development

Two Dockerfiles are available for:
  - compiling, creating the release and running the bot
  - debugging against a real IRC server

To launch everything, follow those steps:

``` bash
    # 1. build and run the bot and ngIRCd (port 6697)
    make docker-dev

    # 2. to stop everything
    make docker-stop
```

You should have the bot running and connected to ngIRCd. You can play with the container as usual,
for example to see the logs `docker attach methal9k.bot`.

For more information or options, checkout the goals available inside the `Makefile`.


# Improvements

If you feel something is wrong with the way Hal is done, I welcome any
suggestion, criticism or contribution.


# License

> This work is free. You can redistribute it and/or modify it under the
> terms of the GPLv3 License. See the LICENSE file for more details.
<!--stackedit_data:
eyJoaXN0b3J5IjpbMTM4MTQ5MjA0OF19
-->