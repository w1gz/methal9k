FROM ubuntu:16.04

## Set some sane ENV value (e.g. for Elixir's UTF8 string)
ENV DEBIAN_FRONTEND noninteractive
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

## Install Ubuntu's dependencies for this project
RUN apt-get update &&\
    apt-get upgrade -fyq &&\
    apt-get install -fyq sudo vim curl git make \
            erlang-nox erlang-dev \
            ngircd supervisor &&\
    apt-get clean &&\
    apt-get autoclean &&\
    rm -rf /tmp/*

## ngIRCd quirks
RUN chown irc:irc /etc/ngircd/ngircd.conf
ADD supervisor.conf /etc/supervisor/conf.d/ngircd.conf

## Create a default user for this container
RUN mkdir -p /home/devel /etc/sudoers.d/ &&\
    echo "devel:x:2133:2133:Devel,,,:/home/devel:/bin/bash" >> /etc/passwd &&\
    echo "devel:x:2133:" >> /etc/group &&\
    echo "devel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/devel &&\
    chmod 0440 /etc/sudoers.d/devel &&\
    chown 2133:2133 -R /home/devel
USER devel
ENV HOME /home/devel
WORKDIR $HOME

## Build Elixir
RUN git clone https://github.com/elixir-lang/elixir $HOME/elixir
RUN cd $HOME/elixir &&\
    make -j3 &&\
    sudo make install &&\
    make clean &&\
    mix local.hex --force

## Build hal
RUN git clone https://github.com/w1gz/methal9k $HOME/hal &&\
    cd $HOME/hal &&\
    mix deps.get &&\
    mix local.rebar --force &&\
    mix compile

EXPOSE 6667

CMD sudo -u root /usr/bin/supervisord
