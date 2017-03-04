#!/bin/bash
set -e
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

if [ "${DEBUG}" = true ]; then
  set -x
fi

OPENDMARC_BUILD_PATH=/build/services/opendmarc

## Install dovecot
apt-get install -y --no-install-recommends opendmarc

mkdir -p /etc/service/opendmarc
cp ${OPENDMARC_BUILD_PATH}/opendmarc.runit /etc/service/opendmarc/run
chmod 750 /etc/service/opendmarc/run


## Configure logrotate.
