# Motivation

This is a good exercise for learning more about Elixir, Erlang and
OTP. Furthermore, Hal greatly benefits from the features provided by OTP:
GenServer, Supervisor or even Hot code loading.


# Installation

## Bare metal

Everything in methal9k is handle by [Mix](https://hexdocs.pm/mix/Mix.html):

``` bash
    mix deps.get
    mix run --no-halt
```

## Docker

A docker-compose configuration is provided with a dedicated container for:
  - compiling the project and creating the release
  - running the release
  - debugging against a real IRC server

To launch everything, follow those steps:

``` bash
    # 1. (optional) launch ngIRCd, it will listen on 6697 by default
    docker-compose up -d ngircd

    # 2. compile the project and create the release
    docker-compose run --rm builder

    # 3. run the bot
    docker-compose run --rm bot
```

Everytime you want to recompile the project, just repeat step 2 and 3.

If you want to stop and remove everything, simply run: `docker-compose down --remove-orphans`.


# Improvements

If you feel something is wrong with the way Hal is done, I welcome any
suggestion, criticism or contribution.


# License

> This work is free. You can redistribute it and/or modify it under the
> terms of the GPLv3 License. See the LICENSE file for more details.
