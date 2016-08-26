#!/bin/bash
set -e
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

if [ "$DEBUG" == true ]; then
  set -x
fi

DOVECOT_BUILD_PATH=/build/services/dovecot

## Install dovecot
apt-get install -y --no-install-recommends dovecot-core dovecot-imapd dovecot-pop3d dovecot-managesieved

mkdir -p /etc/service/dovecot
cp ${DOVECOT_BUILD_PATH}/dovecot.runit /etc/service/dovecot/run
chmod 750 /etc/service/dovecot/run


## Configure logrotate.
