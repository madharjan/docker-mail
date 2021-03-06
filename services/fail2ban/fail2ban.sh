#!/bin/bash
set -e
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

if [ "${DEBUG}" = true ]; then
  set -x
fi

FAIL2BAN_BUILD_PATH=/build/services/fail2ban

## Install fail2ban
apt-get install -y --no-install-recommends \
  iptables \
  fail2ban

echo "ignoreregex =" >> /etc/fail2ban/filter.d/postfix-sasl.conf

mkdir -p /etc/service/fail2ban
cp ${FAIL2BAN_BUILD_PATH}/fail2ban.runit /etc/service/fail2ban/run
chmod 750 /etc/service/fail2ban/run

mkdir -p /var/run/fail2ban

# default disabled
touch /etc/service/fail2ban/down

## Configure logrotate.
