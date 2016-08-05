# docker-smtp
Docker container for Postfix SMTP

## Build

**Clone this project**
```
git clone https://github.com/madharjan/docker-smtp
cd docker-smtp
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
git tag 14.04
git push origin 14.04
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
git clone https://github.com/madharjan/docker-smtp
cd docker-smtp
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
git tag 14.04
git push origin 14.04
```

## Run Container

### Postfix SMTP, Dovecot IMAP/POP3

**Run `docker-mail` container**
```
docker stop mail
docker rm mail

docker run -d -t \
  -p 25:25 \
  -p 587:587 \
  -p 993:993 \
  -p 995:995 \
  -v /opt/docker/mail/config:/tmp/docker-mail \
  -v /opt/docker/mail/data:/var/mail \
  --hostname mail.${DOMAIN}
  --name mail \
  madharjan/docker-mail:14.04 /sbin/my_init
```
