#!/bin/bash
set -e
source /build/config/buildconfig
set -x

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
chmod 750 /usr/local/bin/addmailuser
chmod 750 /usr/local/bin/delmailuser
