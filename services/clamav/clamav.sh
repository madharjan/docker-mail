#!/bin/bash
set -e
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

if [ "${DEBUG}" = true ]; then
  set -x
fi

CLAMAV_BUILD_PATH=/build/services/clamav

## Install clamav
apt-get install -y --no-install-recommends \
  clamav \
  clamav-daemon

sed -i 's/Foreground .*/Foreground true/' /etc/clamav/clamd.conf
sed -i 's/db.local.clamav.net/db.us.clamav.net/' /etc/clamav/freshclam.conf

mkdir -p /etc/service/clamav
cp ${CLAMAV_BUILD_PATH}/clamav.runit /etc/service/clamav/run
chmod 750 /etc/service/clamav/run

mkdir -p /var/run/clamav
chown clamav:clamav /var/run/clamav

crontab - <<EOF
0 0,6,12,18 * * * /usr/bin/freshclam --quiet
EOF

crontab -l

## Configure logrotate.
