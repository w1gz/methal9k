# Motivation

This is a good exercise for learning more about Elixir, Erlang and
OTP. Furthermore, Hal greatly benefits from the features provided by OTP:
GenServer, Supervisor or even Hot code loading.


# Installation

Basic requirements:
- Erlang/OTP-19
- Elixir 1.4


# Running the bot

## Bare metal

Everything in methal9k is handle by [Mix](https://hexdocs.pm/mix/Mix.html)

``` bash
mix deps.get
mix run --no-halt
```

## Docker

Missing an IRC server and/or an Erlang/Elixir installation?

Build and run the dedicated container
``` bash
docker build -t methal9k .
docker run --rm -it methal9k
```

You can then connect to the local IRC server:
 - port: 6667
 - IP: your container's IP ([Can't find the container IP address?](#dockertips))

<a name="dockertips"/>
### Docker tips
Use `docker ps` to find the container_id and `docker inspect <container_id>` to
find the IP.  You will probably need root privilege in order to talk to the
Docker daemon.

Or use the power of `awk` to deliver it to you
``` bash
cid=$(docker ps | awk '$2 == "methal9k" {print $1}')
docker inspect $cid | awk -F '"' '$2 == "IPAddress" {print $4; exit}'
```


# Improvements

If you feel something is wrong with the way Hal is done, I welcome any
suggestion, criticism or contribution.


# License

    This work is free. You can redistribute it and/or modify it under the
    terms of the GPLv3 License. See the LICENSE file for more details.
