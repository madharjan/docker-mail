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
AMAVIS_CONFIG_PATH=/build/config/amavis

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

sed -i 's/#ssl = yes/ssl = yes/' /etc/dovecot/conf.d/10-ssl.conf

## Install SpamAssasin and runit service
/build/services/spamassassin/spamassassin.sh

## Install ClamAV and runit service
/build/services/clamav/clamav.sh

## AV Database
#cp /build/config/main.cvd /var/lib/clamav/main.cvd
#cp /build/config/daily.cvd /var/lib/clamav/daily.cvd
#cp /build/config/bytecode.cvd /var/lib/clamav/bytecode.cvd
/usr/bin/freshclam

## Install Amavis and runit service
/build/services/amavis/amavis.sh
cp ${AMAVIS_CONFIG_PATH}/15-content_filter_mode /etc/amavis/conf.d

adduser clamav amavis
adduser amavis clamav

## Enables Pyzor and Razor
apt-get install -y --no-install-recommends pyzor razor

#sudo -H -u amavis bash -c 'razor-admin -home=/var/lib/amavis/.razor -create'
#sudo -H -u amavis bash -c 'razor-admin -home=/var/lib/amavis/.razor -register'
#sudo -H -u amavis bash -c 'pyzor -home=/var/lib/amavis/.razor discover'

## Install OpenDKIM and runit service
/build/services/opendkim/opendkim.sh

## Install OpenDMARC and runit service
/build/services/opendmarc/opendmarc.sh

## Install Fail2Ban and runit service
/build/services/fail2ban/fail2ban.sh

cp ${FAIL2BAN_CONFIG_PATH}/jail.conf /etc/fail2ban/jail.conf
cp ${FAIL2BAN_CONFIG_PATH}/filter.d/dovecot.conf /etc/fail2ban/filter.d/dovecot.conf

mkdir -p /etc/my_init.d
cp /build/services/20-mail.sh /etc/my_init.d
cp /build/services/21-postfix.sh /etc/my_init.d
chmod 750 /etc/my_init.d/20-mail.sh
chmod 750 /etc/my_init.d/21-postfix.sh

mkdir -p /etc/my_shutdown.d
cp /build/services/80-postfix.sh /etc/my_shutdown.d
cp /build/services/81-fail2ban.sh /etc/my_shutdown.d
chmod 750 /etc/my_shutdown.d/80-postfix.sh
chmod 750 /etc/my_shutdown.d/81-fail2ban.sh

cp /build/bin/add-mail-user /usr/local/bin
cp /build/bin/delete-mail-user /usr/local/bin
cp /build/bin/generate-mail-cert /usr/local/bin
cp /build/bin/generate-dkim-config /usr/local/bin
cp /build/bin/mail-systemd-unit /usr/local/bin

chmod 750 /usr/local/bin/add-mail-user
chmod 750 /usr/local/bin/delete-mail-user
chmod 750 /usr/local/bin/generate-mail-cert
chmod 750 /usr/local/bin/generate-dkim-config
chmod 750 /usr/local/bin/mail-systemd-unit

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
