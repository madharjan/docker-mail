#!/bin/bash
set -e
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

if [ "${DEBUG}" == true ]; then
  set -x
fi

SPAMASSASSIN_BUILD_PATH=/build/services/spamassassin

## Install dovecot
apt-get install -y --no-install-recommends spamassassin
sed -i -r 's/^(CRON|ENABLED)=0/\1=1/g' /etc/default/spamassassin

mkdir -p /etc/service/spamassassin
cp ${SPAMASSASSIN_BUILD_PATH}/spamassassin.runit /etc/service/spamassassin/run
chmod 750 /etc/service/spamassassin/run


## Configure logrotate.
