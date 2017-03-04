#!/bin/bash
set -e
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

if [ "${DEBUG}" = true ]; then
  set -x
fi

POSTFIX_CONFIG_PATH=/build/config/postfix
DOVECOT_CONFIG_PATH=/build/config/dovecot
FAIL2BAN_CONFIG_PATH=/build/config/fail2ban

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

## Install SpamAssasin and runit service
/build/services/spamassassin/spamassassin.sh

## Install ClamAV and runit service
/build/services/clamav/clamav.sh

## AV Database
cp /build/config/main.cvd /var/lib/clamav/main.cvd
cp /build/config/daily.cvd /var/lib/clamav/daily.cvd
cp /build/config/bytecode.cvd /var/lib/clamav/bytecode.cvd
sed -i 's/db.local.clamav.net/db.us.clamav.net/' /etc/clamav/freshclam.conf
#/usr/bin/freshclam

## Install Amavis and runit service
/build/services/amavis/amavis.sh

## Install OpenDKIM and runit service
/build/services/opendkim/opendkim.sh

## Install OpenDMARC and runit service
/build/services/opendmarc/opendmarc.sh

## Install Fail2Ban and runit service
/build/services/fail2ban/fail2ban.sh

cp ${FAIL2BAN_CONFIG_PATH}/jail.conf /etc/fail2ban/jail.conf
cp ${FAIL2BAN_CONFIG_PATH}/filter.d/dovecot.conf /etc/fail2ban/filter.d/dovecot.conf
echo "ignoreregex =" >> /etc/fail2ban/filter.d/postfix-sasl.conf

mkdir -p /etc/my_init.d
cp /build/services/mail-startup.sh /etc/my_init.d
chmod 750 /etc/my_init.d/mail-startup.sh

cp /build/bin/addmailuser /usr/local/bin
cp /build/bin/delmailuser /usr/local/bin
cp /build/bin/generate-dkim-config /usr/local/bin
chmod 750 /usr/local/bin/addmailuser
chmod 750 /usr/local/bin/delmailuser
chmod 750 /usr/local/bin/generate-dkim-config

# Get LetsEncrypt signed certificate
curl -s https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.pem > /etc/ssl/certs/lets-encrypt-x1-cross-signed.pem
curl -s https://letsencrypt.org/certs/lets-encrypt-x2-cross-signed.pem > /etc/ssl/certs/lets-encrypt-x2-cross-signed.pem
curl -s https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem > /etc/ssl/certs/lets-encrypt-x3-cross-signed.pem

## Install CertBot
wget https://dl.eff.org/certbot-auto
cp certbot-auto /usr/local/sbin
chmod a+x /usr/local/sbin/certbot-auto

#/usr/local/sbin/certbot-auto --non-interactive --os-packages-only --logs-dir /var/log/certbot
/usr/local/sbin/certbot-auto --non-interactive --config-dir /etc/certbot --logs-dir /var/log/certbot renew
