# docker-mail
Docker container for Postfix SMTP & Dovecot IMAP/POP3
Based on https://github.com/tomav/docker-mailserver

## Build

**Clone this project**
```
git clone https://github.com/madharjan/docker-mail
cd doocker-mail
```

**Build Container**
```
# login to DockerHub
docker login

# build
make

# test
make test

# tag
make tag_latest

# update Makefile & Changelog.md
# release
make release
```

**Tag and Commit to Git**
```
git tag 2.11-2.2.9
git push origin 2.11-2.2.9
```

### Development Environment
using VirtualBox & Ubuntu Cloud Image (Mac & Windows)

**Install Tools**

* [VirtualBox][virtualbox] 4.3.10 or greater
* [Vagrant][vagrant] 1.6 or greater
* [Cygwin][cygwin] (if using Windows)

Install `vagrant-vbguest` plugin to auto install VirtualBox Guest Addition to virtual machine.
```
vagrant plugin install vagrant-vbguest
```

[virtualbox]: https://www.virtualbox.org/
[vagrant]: https://www.vagrantup.com/downloads.html
[cygwin]: https://cygwin.com/install.html

**Clone this project**

```
git clone https://github.com/madharjan/docker-mail
cd docker-mail
```

**Startup Ubuntu VM on VirtualBox**

```
vagrant up
```

**Build Container**

```
# login to DockerHub
vagrant ssh -c "docker login"  

# build
vagrant ssh -c "cd /vagrant; make"

# test
vagrant ssh -c "cd /vagrant; make test"

# tag
vagrant ssh -c "cd /vagrant; make tag_latest"

# update Makefile & Changelog.md
# release
vagrant ssh -c "cd /vagrant; make release"
```

**Tag and Commit to Git**
```
git tag 2.11-2.2.9
git push origin 2.11-2.2.9
```

## Run Container


### Postfix SMTP, Dovecot IMAP/POP3

**Run Certbot to create SSL certificate for `mail.${DOMAIN}`**
```
docker exec --rm -t \
   -e EMAIL=me@email.com \
   -e DOMAIN=company.com \
   -p 80:80 \
   -p 443:443 \
   -v /opt/docker/certbot:/etc/certbot \
   madharjan/doocker-mail:2.11-2.2.9 /bin/sh -c "/usr/local/sbin/certbot-auto certonly -t -n --no-self-upgrade --agree-tos --standalone --config-dir /etc/certbot -m ${EMAIL} -d mail.${DOMAIN}"
```

**Generate DKIM keys**
```
docker run --rm -t\
  -v /opt/docker/mail/config:/tmp/config \
  madharjan/doocker-mail:2.11-2.2.9 /bin/sh -c "generate-dkim-config"
```
DKIM keys are generated, configure DNS server with DKIM keys from `config/opedkim/keys/domain.tld/mail.txt`

**Create mail users**
```
docker exec --rm -t \
   -e USERNAME=user1 \
   -e DOMAIN=company.com \
   -e PASSWORD=password \
   -v /opt/docker/mail/config:/tmp/config \
   madharjan/doocker-mail:2.11-2.2.9 /bin/sh -c "addmailuser ${USERNAME}@${DOMAIN} ${PASSWORD}"
```

**Run `docker-mail` container**
```
docker stop mail
docker rm mail

docker run -d -t \
  -e ENABLE_POP3=1 \
  -e ENABLE_FAIL2BAN=1 \
  -e ENABLE_SIEVE=1 \
  -e SA_TAG=2.0 \
  -e SA_TAG2=6.31 \
  -e SA_KILL=6.31\
  -e SASL_PASSWD=mysaslpassword \
  -e SMTP_ONLY= \
  -e SSL_TYPE=certbot \
  -p 25:25 \
  -p 587:587 \
  -p 993:993 \
  -p 995:995 \
  -v /opt/docker/mail/config:/tmp/config \
  -v /opt/docker/mail/data:/var/mail \
  -v /opt/docker/mail/log:/var/log/mail \
  -v /opt/docker/certbot:/etc/certbot \
  --hostname mail.${DOMAIN}
  --name mail \
  madharjan/docker-mail:2.11-2.2.9 /sbin/my_init
```
