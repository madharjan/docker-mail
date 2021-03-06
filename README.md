# docker-mail

[![Build Status](https://travis-ci.com/madharjan/docker-mail.svg?branch=master)](https://travis-ci.com/madharjan/docker-mail)
[![Layers](https://images.microbadger.com/badges/image/madharjan/docker-mail.svg)](http://microbadger.com/images/madharjan/docker-mail)

Docker container for Postfix SMTP & Dovecot IMAP/POP3 based on [madharjan/docker-base](https://github.com/madharjan/docker-base/)

Mail Server configuration based on [tomav/docker-mailserver](https://github.com/tomav/docker-mailserver)

## Changes

* Services configured as `runit` services
* Scripts refactor-ed for baseimage `docker-base`

## Features

* Using scripts in `my_init.d` to initialize services (e.g mail-startup.sh)
* Using scripts in `my_shutdown.d` to cleanup services before container stop (e.g postfix-stop.sh)
* Bats ([sstephenson/bats](https://github.com/sstephenson/bats/)) based test cases

### Postfix 2.11 & Dovecot 2.2.9 (docker-mail)

* SpamAssassin 3.4.0
* ClamAV 0.99.2
* Fail2Ban 0.8.11
* Manage Sieve 2.2.9
* Certbot SSL
* OpenDKIM 2.9.1
* OpenDMARC 1.2.0

### Environment

| Variable             | Default | Example                  |
| -------------------- | ------- | ------------------------ |
| DISABLE_AMAVIS       |         | 1 (to disable)           |
| DISABLE_CLAMAV       |         | 1 (to disable)           |
| DISABLE_SPAMASSASSIN |         | 1 (to disable)           |
| ENABLE_FAIL2BAN      |         | 1 (to enable)            |
| ENABLE_MANAGESIEVE   |         | 1 (to enable)            |
| ENABLE_POP3          |         | 1 (to enable)            |
| SMTP_ONLY            |         | 1 (to enable)            |
| SSL_TYPE             |         | certbot                  |
| SASL_PASSWD          |         | domain username:password |
| SA_TAG               |         | 2.0                      |
| SA_TAG2              |         | 6.31                     |
| SA_KILL              |         | 6.31                     |

## Build

```bash
# clone project
git clone https://github.com/madharjan/docker-mail
cd docker-mail

# build
make

# tests
make run
make fixtures
make test

# clean
make clean
```

## Run

**Note**: update environment variables below as necessary

### Postfix SMTP, Dovecot IMAP/POP3

**Run Certbot to create SSL certificate for `mail.${DOMAIN}`**

```bash
docker run --rm \
   -e EMAIL=me@email.com \
   -e DOMAIN=company.com \
   -p 80:80 \
   -p 443:443 \
   -v /opt/docker/certbot:/etc/certbot \
   madharjan/doocker-mail:3.10-2.2.22 \
   generate-mail-cert
```

**Generate DKIM keys**

```bash
docker run --rm \
  -v /opt/docker/mail/config:/tmp/config \
  madharjan/docker-mail:3.10-2.2.22 \
  generate-dkim-config
```

DKIM keys are generated, configure DNS server with DKIM keys from `config/opedkim/keys/domain.tld/mail.txt`

**Create mail users**

```bash
docker exec --rm \
   -e EMAIL=user1 \
   -e PASSWORD=password \
   -v /opt/docker/mail/config:/tmp/config \
   madharjan/doocker-mail:3.10-2.2.22 \
   add-mail-user
```

**Run `docker-mail` container**

```bash
docker stop mail
docker rm mail

docker run -d \
  -e ENABLE_POP3=1 \
  -e ENABLE_FAIL2BAN=1 \
  -e ENABLE_MANAGESIEVE=1 \
  -e SA_TAG=2.0 \
  -e SA_TAG2=6.31 \
  -e SA_KILL=6.31\
  -e SMTP_ONLY= \
  -e SSL_TYPE=certbot \
  -p 25:25 \
  -p 587:587 \
  -p 993:993 \
  -p 995:995 \
  -v /opt/docker/mail/config:/tmp/config \
  -v /opt/docker/mail/data:/var/mail \
  -v /opt/docker/mail/log:/var/log/mail \
  -v /opt/docker/certbot:/etc/certbot \
  --hostname mail.${DOMAIN}
  --name mail \
  madharjan/docker-mail:3.10-2.2.22
```

## Systemd Unit File

**Note**: update environment variables below as necessary

```txt
[Unit]
Description=Mail

After=docker.service

[Service]
TimeoutStartSec=0

ExecStartPre=-/bin/mkdir -p /opt/docker/mail
ExecStartPre=-/usr/bin/docker stop mail
ExecStartPre=-/usr/bin/docker rm mail
ExecStartPre=-/usr/bin/docker pull madharjan/docker-mail:3.10-2.2.22

ExecStart=/usr/bin/docker run \
  -e ENABLE_POP3=1 \
  -e ENABLE_FAIL2BAN=1 \
  -e ENABLE_MANAGESIEVE=1 \
  -e SA_TAG=2.0 \
  -e SA_TAG2=6.31 \
  -e SA_KILL=6.31\
  -e SMTP_ONLY= \
  -e SSL_TYPE=certbot \
  -p 25:25 \
  -p 587:587 \
  -p 993:993 \
  -p 995:995 \
  -v /opt/docker/mail/config:/tmp/config \
  -v /opt/docker/mail/data:/var/mail \
  -v /opt/docker/mail/log:/var/log/mail \
  -v /opt/docker/certbot:/etc/certbot \
  --hostname mail.${DOMAIN}
  --name mail \
  madharjan/docker-mail:3.10-2.2.22

ExecStop=/usr/bin/docker stop -t 2 mail

[Install]
WantedBy=multi-user.target
```

## Generate Systemd Unit File

| Variable             | Default                       | Example                      |
| -------------------- | ----------------------------- | ---------------------------- |
| VOLUME_HOME          | /opt/docker                   | /opt/data                    |
| NAME                 | mail                          |                              |
|                      |                               |                              |
| DOMAIN               |                               | mycompany.com                |
| DISABLE_AMAVIS       | 0                             | 1 (to disable)               |
| DISABLE_CLAMAV       | 0                             | 1 (to disable)               |
| DISABLE_SPAMASSASSIN | 0                             | 1 (to disable)               |
| ENABLE_FAIL2BAN      | 0                             | 1 (to enable)                |
| ENABLE_MANAGESIEVE   | 0                             | 1 (to enable)                |
| ENABLE_POP3          | 0                             | 1 (to enable)                |
| SMTP_ONLY            | 0                             | 1 (to enable)                |
| SSL_TYPE             | certbot                       |                              |
| SASL_PASSWD          |                               | domain.com username:password |
| SA_TAG               | 2.0                           |                              |
| SA_TAG2              | 6.31                          |                              |
| SA_KILL              | 6.31                          |                              |
| PORTS                | 25:25,587:587,993:993,995:995 |                              |

```bash
# generate mail.service
docker run --rm \
  -e VOLUME_HOME=/opt/docker \
  -e NAME=mail \
  -e DOMAIN=mycompany.com \
  madharjan/docker-mail:3.10-2.2.22 \
  mail-systemd-unit | \
  sudo tee /etc/systemd/system/mail.service

sudo systemctl enable mail
sudo systemctl start mail
```
