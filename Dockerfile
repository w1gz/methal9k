FROM ubuntu:17.10

RUN apt-get update &&\
    apt-get upgrade -fyq &&\
    apt-get install -fyq ngircd locales openssl &&\
    apt-get clean &&\
    apt-get autoclean &&\
    rm -rf /tmp/*

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN cd /etc/ngircd &&\
    echo "methal9k - ircd" > ngircd.motd &&\
    sed -i "s#;CertFile = /etc/ssl/certs/server.crt#CertFile = /etc/ngircd/server.crt#g" ngircd.conf &&\
    sed -i "s#;KeyFile = /etc/ssl/private/server.key#KeyFile = /etc/ngircd/server.key#g" ngircd.conf &&\
    sed -i "s#;Ports = 6697, 9999#Ports = 6697#g" ngircd.conf &&\
    sed -i "s#CipherList = SECURE128:-VERS-SSL3.0#CipherList = NORMAL:-VERS-SSL3.0#g" ngircd.conf &&\
    openssl req -newkey rsa:2048 -x509 -days 365 -nodes \
        -keyout server.key -out server.crt \
        -subj "/C=/ST=/L=/O=/CN=localhost" &&\
    chown -R irc:irc . &&\
    chmod 400 server.key server.crt

USER irc

EXPOSE 6697

ENTRYPOINT /usr/sbin/ngircd -n -f /etc/ngircd/ngircd.conf
