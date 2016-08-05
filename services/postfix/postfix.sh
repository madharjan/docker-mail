#!/bin/bash
set -e
source /build/config/buildconfig
set -x

POSTFIX_BUILD_PATH=/build/services/postfix

## Install postfix
$minimal_apt_get_install postfix postfix-ldap ssl-cert

mkdir -p /etc/service/postfix
cp ${POSTFIX_BUILD_PATH}/postfix.runit /etc/service/postfix/run
chmod 750 /etc/service/postfix/run
#cp ${POSTFIX_BUILD_PATH}/postfix.finish /etc/service/postfix/finish
#chmod 750 /etc/service/postfix/finish

## Add user vmal
groupadd -g 5000 vmail
useradd -u 5000 -g vmail -s /sbin/nologin -d /var/mail vmail
chown -R vmail:vmail /var/mail

## Configure logrotate.
mkdir -p /var/log/mail
chown root:syslog /var/log/mail
sed -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/syslog-ng/syslog-ng.conf
sed -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/logrotate.d/syslog-ng
