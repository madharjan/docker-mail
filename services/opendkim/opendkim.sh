#!/bin/bash
set -e
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

if [ "${DEBUG}" == true ]; then
  set -x
fi

OPENDKIM_BUILD_PATH=/build/services/opendkim

## Install dovecot
apt-get install -y --no-install-recommends \
  opendkim \
  opendkim-tools

mkdir -p /etc/service/opendkim
cp ${OPENDKIM_BUILD_PATH}/opendkim.runit /etc/service/opendkim/run
chmod 750 /etc/service/opendkim/run

## Configure logrotate.
