#!/bin/bash
set -e
source /build/config/buildconfig
set -x

DOVECOT_BUILD_PATH=/build/services/dovecot

## Install dovecot
$minimal_apt_get_install dovecot-core dovecot-imapd dovecot-pop3d dovecot-ldap

mkdir -p /etc/service/dovecot
cp ${DOVECOT_BUILD_PATH}/dovecot.runit /etc/service/dovecot/run
chmod 750 /etc/service/dovecot/run


## Configure logrotate.
