FROM madharjan/docker-base:16.04
MAINTAINER Madhav Raj Maharjan <madhav.maharjan@gmail.com>

ARG VCS_REF
ARG POSTFIX_VERSION
ARG DOVECOT_VERSION
ARG DEBUG=false

LABEL description="Docker container for Postfix SMTP, Dovecot IMAP/POP3" os_version="Ubuntu ${UBUNTU_VERSION}" \
      org.label-schema.vcs-ref=${VCS_REF} org.label-schema.vcs-url="https://github.com/madharjan/docker-mail"

ENV POSTFIX_VERSION ${POSTFIX_VERSION}
ENV DOVECOT_VERSION ${DOVECOT_VERSION}

RUN mkdir -p /build
COPY . /build

RUN chmod 755 /build/scripts/*.sh && /build/scripts/install.sh && /build/scripts/cleanup.sh

VOLUME ["/etc/postfix","/etc/dovecot","/var/mail","/var/log/mail"]

CMD ["/sbin/my_init"]

EXPOSE 25 587 993 995
