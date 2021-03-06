#!/bin/bash

set -e

if [ "${DEBUG}" = true ]; then
  set -x
fi

DISABLE_AMAVIS=${DISABLE_AMAVIS:-}
DISABLE_CLAMAV=${DISABLE_CLAMAV:-}
DISABLE_SPAMASSASSIN=${DISABLE_SPAMASSASSIN:-}
ENABLE_FAIL2BAN=${ENABLE_FAIL2BAN:-}
ENABLE_MANAGESIEVE=${ENABLE_MANAGESIEVE:-}
ENABLE_POP3=${ENABLE_POP3:-}
SMTP_ONLY=${SMTP_ONLY:-}
SASL_PASSWD=${SASL_PASSWD:-}
SA_TAG=${SA_TAG:-}
SA_TAG2=${SA_TAG2:-}
SA_KILL=${SA_KILL:-}
SSL_TYPE=${SSL_TYPE:-NONE}

# Users
if [ -f /tmp/config/postfix-accounts.cf ]; then
  echo "Configuring Postfix & Dovecot"
  # Checking file line endings
  sed -i 's/\r//g' /tmp/config/postfix-accounts.cf
  echo "Regenerating postfix 'vmailbox' and 'virtual' for users"
  echo "# WARNING: this file is auto-generated. Modify config/postfix-accounts.cf to edit user list." > /etc/postfix/vmailbox

  # Checking that /tmp/config/postfix-accounts.cf ends with a newline
  sed -i -e '$a\' /tmp/config/postfix-accounts.cf

  echo -n > /etc/dovecot/userdb
  chown dovecot:dovecot /etc/dovecot/userdb
  chmod 640 /etc/dovecot/userdb

  # Disable now, enabled later in the script if requested
  cp -a /usr/share/dovecot/protocols.d /etc/dovecot
  mv /etc/dovecot/protocols.d/pop3d.protocol /etc/dovecot/protocols.d/pop3d.protocol.disabled
  mv /etc/dovecot/protocols.d/managesieved.protocol /etc/dovecot/protocols.d/managesieved.protocol.disabled

  # Creating users
  # 'pass' is encrypted
  while IFS=$'|' read login pass
  do
    # Setting variables for better readability
    user=$(echo ${login} | cut -d @ -f1)
    domain=$(echo ${login} | cut -d @ -f2)

    echo "user '${user}' for domain '${domain}' with password '********'"
    echo "${login} ${domain}/${user}/" >> /etc/postfix/vmailbox

    # User database for dovecot has the following format:
    # user:password:uid:gid:(gecos):home:(shell):extra_fields
    # ${login}:${pass}:5000:5000::/var/mail/${domain}/${user}::userdb_mail=maildir:/var/mail/${domain}/${user}
    echo "${login}:${pass}:5000:5000::/var/mail/${domain}/${user}::" >> /etc/dovecot/userdb

    mkdir -p /var/mail/${domain}
    if [ ! -d "/var/mail/${domain}/${user}" ]; then
      maildirmake.dovecot "/var/mail/${domain}/${user}"
      maildirmake.dovecot "/var/mail/${domain}/${user}/.Sent"
      maildirmake.dovecot "/var/mail/${domain}/${user}/.Trash"
      maildirmake.dovecot "/var/mail/${domain}/${user}/.Drafts"
      echo -e "INBOX\nSent\nTrash\nDrafts" >> "/var/mail/${domain}/${user}/subscriptions"
      touch "/var/mail/${domain}/${user}/.Sent/maildirfolder"
    fi
    echo ${domain} >> /tmp/vhost.tmp
  done < /tmp/config/postfix-accounts.cf
else
  echo "==> Warning: 'config/config/postfix-accounts.cf' is not provided. No mail account created."
fi

# Aliases
if [ -f /tmp/config/postfix-virtual.cf ]; then
  # Copying virtual file
  cp /tmp/config/postfix-virtual.cf /etc/postfix/virtual
  while read from to
  do
    # Setting variables for better readability
    uname=$(echo ${from} | cut -d @ -f1)
    domain=$(echo ${from} | cut -d @ -f2)
    # if they are equal it means the line looks like: "user1     other@domain.tld"
    test "$uname" != "$domain" && echo ${domain} >> /tmp/vhost.tmp
  done < /tmp/config/postfix-virtual.cf
else
  echo "==> Warning: 'config/postfix-virtual.cf' is not provided. No mail alias/forward created."
fi

if [ -f /tmp/config/postfix-regexp.cf ]; then
  # Copying regexp alias file
  echo "Adding regexp alias file postfix-regexp.cf"
  cp /tmp/config/postfix-regexp.cf /etc/postfix/regexp
  sed -i -e '/^virtual_alias_maps/{
    s/ regexp:.*//
    s/$/ regexp:\/etc\/postfix\/regexp/
    }' /etc/postfix/main.cf
fi

# DKIM
# Check if keys are already available
if [ -e "/tmp/config/opendkim/KeyTable" ]; then
  mkdir -p /etc/opendkim
  cp -a /tmp/config/opendkim/* /etc/opendkim/
  echo "DKIM keys added for: `ls -C /etc/opendkim/keys/`"
  echo "Changing permissions on /etc/opendkim"
  # chown entire directory
  chown -R opendkim:opendkim /etc/opendkim/
  # And make sure permissions are right
  chmod -R 0700 /etc/opendkim/keys/
else
  echo "No DKIM key provided. Check the documentation to find how to get your keys."
fi

# DMARC
# if there is no AuthservID create it
if [ `cat /etc/opendmarc.conf | grep -e '^AuthservID .*' | wc -l` -eq 0 ]; then
  echo "AuthservID $(hostname)" >> /etc/opendmarc.conf
fi
if [ `cat /etc/opendmarc.conf | grep -e '^TrustedAuthservIDs .*' | wc -l` -eq 0 ]; then
  echo "TrustedAuthservIDs $(hostname)" >> /etc/opendmarc.conf
fi
if [ -f "/etc/opendmarc/ignore.hosts" ]; then
  echo "ignore.hosts already exists"
else
  mkdir -p /etc/opendmarc/
  echo "localhost" >> /etc/opendmarc/ignore.hosts
fi

# SSL Configuration
case $SSL_TYPE in
  "certbot" )
    # certbot folders and files mounted in /etc/certbot
    if [ -e "/etc/certbot/live/$(hostname)/cert.pem" ] \
    && [ -e "/etc/certbot/live/$(hostname)/chain.pem" ] \
    && [ -e "/etc/certbot/live/$(hostname)/fullchain.pem" ] \
    && [ -e "/etc/certbot/live/$(hostname)/privkey.pem" ]; then
      echo "Adding $(hostname) SSL certificate"
      # create combined.pem from (cert|chain|privkey).pem with eol after each .pem
      sed -e '$a\' -s /etc/certbot/live/$(hostname)/{cert,chain,privkey}.pem > /etc/certbot/live/$(hostname)/combined.pem

      # Postfix configuration
      sed -i -r 's/smtpd_tls_cert_file=\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/smtpd_tls_cert_file=\/etc\/certbot\/live\/'$(hostname)'\/fullchain.pem/g' /etc/postfix/main.cf
      sed -i -r 's/smtpd_tls_key_file=\/etc\/ssl\/private\/ssl-cert-snakeoil.key/smtpd_tls_key_file=\/etc\/certbot\/live\/'$(hostname)'\/privkey.pem/g' /etc/postfix/main.cf

      # Dovecot configuration
      sed -i -e 's/#ssl_cert = <\/etc\/dovecot\/dovecot\.pem/ssl_cert = <\/etc\/certbot\/live\/'$(hostname)'\/fullchain\.pem/g' /etc/dovecot/conf.d/10-ssl.conf
      sed -i -e 's/#ssl_key = <\/etc\/dovecot\/private\/dovecot\.pem/ssl_key = <\/etc\/certbot\/live\/'$(hostname)'\/privkey\.pem/g' /etc/dovecot/conf.d/10-ssl.conf
      sed -i -e 's/ssl = no/ssl = required/g' /etc/dovecot/conf.d/10-ssl.conf

      echo "SSL configured with 'certbot' certificates"
    fi
    ;;

  "self-signed" )
    # Adding self-signed SSL certificate if provided in '/tmp/config/ssl' folder
    if [ -e "/tmp/config/ssl/$(hostname)-cert.pem" ] \
    && [ -e "/tmp/config/ssl/$(hostname)-key.pem"  ] \
    && [ -e "/tmp/config/ssl/$(hostname)-combined.pem" ] \
    && [ -e "/tmp/config/ssl/cacert.pem" ]; then
      echo "Adding $(hostname) SSL certificate"
      mkdir -p /etc/postfix/ssl
      cp "/tmp/config/ssl/$(hostname)-cert.pem" /etc/postfix/ssl
      cp "/tmp/config/ssl/$(hostname)-key.pem" /etc/postfix/ssl
      # Force permission on key file
      chmod 600 /etc/postfix/ssl/$(hostname)-key.pem
      cp "/tmp/config/ssl/$(hostname)-combined.pem" /etc/postfix/ssl
      cp /tmp/config/ssl/cacert.pem /etc/postfix/ssl

      # Postfix configuration
      sed -i -r 's/smtpd_tls_cert_file=\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/smtpd_tls_cert_file=\/etc\/postfix\/ssl\/'$(hostname)'-cert.pem/g' /etc/postfix/main.cf
      sed -i -r 's/smtpd_tls_key_file=\/etc\/ssl\/private\/ssl-cert-snakeoil.key/smtpd_tls_key_file=\/etc\/postfix\/ssl\/'$(hostname)'-key.pem/g' /etc/postfix/main.cf
      sed -i -r 's/#smtpd_tls_CAfile=/smtpd_tls_CAfile=\/etc\/postfix\/ssl\/cacert.pem/g' /etc/postfix/main.cf
      sed -i -r 's/#smtp_tls_CAfile=/smtp_tls_CAfile=\/etc\/postfix\/ssl\/cacert.pem/g' /etc/postfix/main.cf
      ln -s /etc/postfix/ssl/cacert.pem "/etc/ssl/certs/cacert-$(hostname).pem"

      # Dovecot configuration
      sed -i -e 's/#ssl_cert = <\/etc\/dovecot\/dovecot\.pem/ssl_cert = <\/etc\/postfix\/ssl\/'$(hostname)'-combined\.pem/g' /etc/dovecot/conf.d/10-ssl.conf
      sed -i -e 's/#ssl_key = <\/etc\/dovecot\/private\/dovecot\.pem/ssl_key = <\/etc\/postfix\/ssl\/'$(hostname)'-key\.pem/g' /etc/dovecot/conf.d/10-ssl.conf
      sed -i -e 's/ssl = no/ssl = required/g' /etc/dovecot/conf.d/10-ssl.conf

      echo "SSL configured with 'self-signed' certificates"

    fi
    ;;

    "NONE" )
      # Dovecot configuration
      sed -i -e 's/#ssl_cert = <\/etc\/dovecot\/dovecot\.pem/ssl_cert = <\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/g' /etc/dovecot/conf.d/10-ssl.conf
      sed -i -e 's/#ssl_key = <\/etc\/dovecot\/private\/dovecot\.pem/ssl_key = <\/etc\/ssl\/private\/ssl-cert-snakeoil.key/g' /etc/dovecot/conf.d/10-ssl.conf
      sed -i -e 's/ssl = no/ssl = required/g' /etc/dovecot/conf.d/10-ssl.conf
    ;;
esac

if [ -f /tmp/vhost.tmp ]; then
  cat /tmp/vhost.tmp | sort | uniq > /etc/postfix/vhost && rm /tmp/vhost.tmp
fi

echo "Postfix configurations"
touch /etc/postfix/vmailbox && postmap /etc/postfix/vmailbox
touch /etc/postfix/virtual && postmap /etc/postfix/virtual

# PERMIT_DOCKER Option
container_ip=$(ip addr show eth0 | grep 'inet ' | sed 's/[^0-9\.\/]*//g' | cut -d '/' -f 1)
container_network="$(echo $container_ip | cut -d '.' -f1-2).0.0"
case $PERMIT_DOCKER in
  "host" )
      echo "Adding $container_network/16 to my networks"
      postconf -e "$(postconf | grep '^mynetworks =') $container_network/16"
      bash -c "echo $container_network/16 >> /etc/opendmarc/ignore.hosts"
      bash -c "echo $container_network/16 >> /etc/opendkim/TrustedHosts"
    ;;

  "network" )
      echo "Adding docker network in my networks"
      postconf -e "$(postconf | grep '^mynetworks =') 172.16.0.0/12"
      bash -c "echo 172.16.0.0/12 >> /etc/opendmarc/ignore.hosts"
      bash -c "echo 172.16.0.0/12 >> /etc/opendkim/TrustedHosts"
    ;;

  * )
      echo "Adding container ip in my networks"
      postconf -e "$(postconf | grep '^mynetworks =') $container_ip/32"
      bash -c "echo $container_ip/32 >> /etc/opendmarc/ignore.hosts"
      bash -c "echo $container_ip/32 >> /etc/opendkim/TrustedHosts"
    ;;

esac

# Override Postfix configuration
if [ -f /tmp/config/postfix-main.cf ]; then
  while read line; do
    postconf -e "$line"
  done < /tmp/config/postfix-main.cf
  echo "Loaded 'config/postfix-main.cf'"
else
  echo "No extra postfix settings loaded because optional '/tmp/config/postfix-main.cf' not provided."
fi

# Support general SASL password
rm -f /etc/postfix/sasl_passwd
if [ ! -z "$SASL_PASSWD" ]; then
  echo "$SASL_PASSWD" >> /etc/postfix/sasl_passwd
fi

# Install SASL passwords
if [ -f /etc/postfix/sasl_passwd ]; then
  postmap hash:/etc/postfix/sasl_passwd
  rm /etc/postfix/sasl_passwd
  chown root:root /etc/postfix/sasl_passwd.db
  chmod 0600 /etc/postfix/sasl_passwd.db
  echo "Loaded SASL_PASSWD"
else
  echo "==> Warning: 'SASL_PASSWD' is not provided. /etc/postfix/sasl_passwd not created."
fi

# Fix permissions, but skip this if 3 levels deep the user id is already set
if [ `find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | grep -c .` != 0 ]; then
  echo "Fixing /var/mail permissions"
  chown -R 5000:5000 /var/mail
else
  echo "Permissions in /var/mail look OK"
fi

echo "Creating /etc/mailname"
echo $(hostname -d) > /etc/mailname

echo "Configuring Spamassassin"
SA_TAG=${SA_TAG:="2.0"} && sed -i -r 's/^\$sa_tag_level_deflt (.*);/\$sa_tag_level_deflt = '$SA_TAG';/g' /etc/amavis/conf.d/20-debian_defaults
SA_TAG2=${SA_TAG2:="6.31"} && sed -i -r 's/^\$sa_tag2_level_deflt (.*);/\$sa_tag2_level_deflt = '$SA_TAG2';/g' /etc/amavis/conf.d/20-debian_defaults
SA_KILL=${SA_KILL:="6.31"} && sed -i -r 's/^\$sa_kill_level_deflt (.*);/\$sa_kill_level_deflt = '$SA_KILL';/g' /etc/amavis/conf.d/20-debian_defaults
test -e /tmp/config/spamassassin-rules.cf && cp /tmp/config/spamassassin-rules.cf /etc/spamassassin/

if [ "$ENABLE_FAIL2BAN" = 1 ]; then
  echo "Fail2ban enabled"
  test -e /tmp/config/fail2ban-jail.cf && cp /tmp/config/fail2ban-jail.cf /etc/fail2ban/jail.local
else
  # Disable logrotate config for fail2ban if not enabled
  rm -f /etc/logrotate.d/fail2ban
fi

# Fix cron.daily for spamassassin
sed -i -e 's/invoke-rc.d spamassassin reload/sv 1 spamassassin/g' /etc/cron.daily/spamassassin

# Consolidate all state that should be persisted across container restarts into one mounted
# directory
#statedir=/var/mail-state
#if [ "$ONE_DIR" = 1 -a -d $statedir ]; then
#  echo "Consolidating all state onto $statedir"
#  for d in /var/spool/postfix /var/lib/postfix /var/lib/amavis /var/lib/clamav /var/lib/spamassasin /var/lib/fail2ban; do
#    dest=$statedir/`echo $d | sed -e 's/.var.//; s/\//-/g'`
#    if [ -d $dest ]; then
#      echo "  Destination $dest exists, linking $d to it"
#      rm -rf $d
#      ln -s $dest $d
#    elif [ -d $d ]; then
#      echo "  Moving contents of $d to $dest:" `ls $d`
#      mv $d $dest
#      ln -s $dest $d
#    else
#      echo "  Linking $d to $dest"
#      mkdir -p $dest
#      ln -s $dest $d
#    fi
#  done
#fi

# Enable Managesieve service by setting the symlink
# to the configuration file Dovecot will actually find
if [ "$ENABLE_MANAGESIEVE" = 1 ]; then
  echo "Sieve management enabled"
  mv /etc/dovecot/protocols.d/managesieved.protocol.disabled /etc/dovecot/protocols.d/managesieved.protocol
fi

if [ "$SMTP_ONLY" = 1 ]; then
  # Here we are starting sasl and imap, not pop3 because it's disabled by default
  echo "Disabling dovecot services"
  touch /etc/service/dovecot/down
fi

if [ "$ENABLE_POP3" = 1 -a "$SMTP_ONLY" != 1 ]; then
  echo "Enabling POP3 services"
  mv /etc/dovecot/protocols.d/pop3d.protocol.disabled /etc/dovecot/protocols.d/pop3d.protocol
fi

if [ -f /tmp/config/dovecot.cf ]; then
  cp /tmp/config/dovecot.cf /etc/dovecot/local.conf
fi

# Start services related to SMTP
if [ "$DISABLE_SPAMASSASSIN" = 1 ]; then
  echo "Disabling spamassassin services"
  touch /etc/service/spamassassin/down
fi
if [ "$DISABLE_CLAMAV" = 1 ]; then
  echo "Disabling clamav services"
  touch /etc/service/clamav/down
fi
if [ "$DISABLE_AMAVIS" = 1 ]; then
  echo "Disabling amavis services"
  touch /etc/service/amavis/down
fi

if [ "$ENABLE_FAIL2BAN" = 1 ]; then
  echo "Enabling fail2ban service"
  touch /var/log/auth.log
  rm -rf /etc/service/fail2ban/down
fi

exit 0
