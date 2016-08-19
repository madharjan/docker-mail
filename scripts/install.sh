#!/bin/bash
set -e
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

if [ "$DEBUG" == true ]; then
  set -x
fi

POSTFIX_CONFIG_PATH=/build/config/postfix
DOVECOT_CONFIG_PATH=/build/config/dovecot

apt-get update
apt-get upgrade -y --no-install-recommends

## Install Postfix and runit service
/build/services/postfix/postfix.sh
cp ${POSTFIX_CONFIG_PATH}/main.cf /etc/postfix
cp ${POSTFIX_CONFIG_PATH}/master.cf /etc/postfix

## Install Dovecot and runit service
/build/services/dovecot/dovecot.sh
cp ${DOVECOT_CONFIG_PATH}/dovecot.conf /etc/dovecot
cp ${DOVECOT_CONFIG_PATH}/??-*.conf /etc/dovecot/conf.d
cp ${DOVECOT_CONFIG_PATH}/auth-*.conf.ext /etc/dovecot/conf.d

mkdir -p /etc/my_init.d
cp /build/services/mail-startup.sh /etc/my_init.d
chmod 750 /etc/my_init.d/mail-startup.sh

cp /build/bin/addmailuser /usr/local/bin
cp /build/bin/delmailuser /usr/local/bin
cp /build/bin/generate-dkim-config /usr/local/bin
chmod 750 /usr/local/bin/addmailuser
chmod 750 /usr/local/bin/delmailuser
chmod 750 /usr/local/bin/generate-dkim-config

## Install CertBot
wget https://dl.eff.org/certbot-auto
cp certbot-auto /usr/local/sbin
chmod a+x /usr/local/sbin/certbot-auto

#/usr/local/sbin/certbot-auto --non-interactive --os-packages-only
/usr/local/sbin/certbot-auto -t --non-interactive renew
