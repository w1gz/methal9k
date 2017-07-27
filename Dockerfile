FROM ubuntu:17.04

## Install dependencies for this project
RUN apt-get update &&\
    apt-get upgrade -fyq &&\
    apt-get install -fyq locales sudo vim curl git make \
            erlang-nox erlang-dev \
            ngircd supervisor &&\
    apt-get clean &&\
    apt-get autoclean &&\
    rm -rf /tmp/*

## Set some sane value
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

## ngIRCd quirks
RUN cd /etc/ngircd &&\
    sed -i "s#;CertFile = /etc/ssl/certs/server.crt#CertFile = /etc/ngircd/server.crt#g" ngircd.conf &&\
    sed -i "s#;KeyFile = /etc/ssl/private/server.key#KeyFile = /etc/ngircd/server.key#g" ngircd.conf &&\
    sed -i "s#;Ports = 6697, 9999#Ports = 6697#g" ngircd.conf &&\
    openssl req -newkey rsa:2048 -x509 -days 365 -nodes \
        -keyout server.key -out server.crt \
        -subj "/C=/ST=/L=/O=/CN=localhost" &&\
    chown -R irc:irc . &&\
    chmod 400 server.key server.crt &&\
    cp server.crt /usr/local/share/ca-certificates &&\
    update-ca-certificates

## Create a default user for this container
RUN mkdir -p /home/dev /etc/sudoers.d/ &&\
    echo "dev:x:2133:2133:Dev,,,:/home/dev:/bin/bash" >> /etc/passwd &&\
    echo "dev:x:2133:" >> /etc/group &&\
    echo "dev ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/dev &&\
    chmod 0440 /etc/sudoers.d/dev &&\
    chown 2133:2133 -R /home/dev
USER dev
ENV HOME /home/dev
WORKDIR $HOME

## Build Elixir
RUN git clone --branch v1.5 https://github.com/elixir-lang/elixir $HOME/elixir
RUN cd $HOME/elixir &&\
    make -j5 &&\
    sudo make install &&\
    make clean &&\
    mix local.hex --force

## Build hal
RUN git clone https://github.com/w1gz/methal9k $HOME/hal &&\
    cd $HOME/hal &&\
    mix deps.get &&\
    mix local.rebar --force &&\
    mix compile &&\
    sudo cp $HOME/hal/supervisor.conf /etc/supervisor/conf.d/ngircd.conf

EXPOSE 6667

CMD sudo -u root /usr/bin/supervisord -c $HOME/hal/supervisor.conf
