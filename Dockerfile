FROM madharjan/docker-base:14.04
MAINTAINER Madhav Raj Maharjan <madhav.maharjan@gmail.com>

LABEL description="Docker container for Postfix SMTP, Dovecot IMAP/POP3" os_version="Ubuntu 14.04"

ENV HOME /root
ARG DEBUG=false

RUN mkdir -p /build
COPY . /build

RUN /build/scripts/install.sh && /build/scripts/cleanup.sh

VOLUME ["/etc/postfix","/etc/dovecot","/var/mail","/var/log/mail"]

CMD ["/sbin/my_init"]

EXPOSE 25 587 993 995
