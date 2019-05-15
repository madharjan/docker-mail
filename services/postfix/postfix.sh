#!/bin/bash
set -e
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

if [ "${DEBUG}" = true ]; then
  set -x
fi

POSTFIX_BUILD_PATH=/build/services/postfix

## Install postfix
apt-get install -y --no-install-recommends \
  postfix \
  ssl-cert \
  netcat \
  iproute

mkdir -p /etc/service/postfix
cp ${POSTFIX_BUILD_PATH}/postfix.runit /etc/service/postfix/run
chmod 750 /etc/service/postfix/run

## Add user vmal
groupadd -g 5000 vmail
useradd -u 5000 -g vmail -s /sbin/nologin -d /var/mail vmail
chown -R vmail:vmail /var/mail

## Configure logrotate.
mkdir -p /var/log/mail
chown root:adm /var/log/mail
sed -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/syslog-ng/syslog-ng.conf
sed -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/logrotate.d/syslog-ng
