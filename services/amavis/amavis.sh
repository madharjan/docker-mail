#!/bin/bash
set -e
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

if [ "${DEBUG}" = true ]; then
  set -x
fi

AMAVIS_BUILD_PATH=/build/services/amavis

## Install dovecot
apt-get install -y --no-install-recommends \
  amavisd-new \
  bzip2 \
  file \
  gzip \
  p7zip \
  unzip \
  arj \
  unrar \
  cabextract \
  zip

mkdir -p /etc/service/amavis
cp ${AMAVIS_BUILD_PATH}/amavis.runit /etc/service/amavis/run
chmod 750 /etc/service/amavis/run

## Configure logrotate.
