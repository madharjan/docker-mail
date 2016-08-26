#!/bin/bash
set -e
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

if [ "$DEBUG" == true ]; then
  set -x
fi

CLAMAV_BUILD_PATH=/build/services/clamav

## Install dovecot
apt-get install -y --no-install-recommends clamav clamav-daemon
mkdir -p /etc/service/clamav
cp ${CLAMAV_BUILD_PATH}/clamav.runit /etc/service/clamav/run
chmod 750 /etc/service/clamav/run

mkdir -p /var/run/clamav
chown clamav:clamav /var/run/clamav

## Configure logrotate.