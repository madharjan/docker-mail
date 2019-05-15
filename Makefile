
NAME = madharjan/docker-mail
POSTFIX_VERSION = 2.11
DOVECOT_VERSION = 2.2.9
VERSION = $(POSTFIX_VERSION)-$(DOVECOT_VERSION)

DEBUG ?= true

DOCKER_USERNAME ?= $(shell read -p "DockerHub Username: " pwd; echo $$pwd)
DOCKER_PASSWORD ?= $(shell stty -echo; read -p "DockerHub Password: " pwd; stty echo; echo $$pwd)
DOCKER_LOGIN ?= $(shell cat ~/.docker/config.json | grep "docker.io" | wc -l)

.PHONY: all build generate_users run fixtures test stop clean tag_latest release clean_images

all: build

docker_login:
ifeq ($(DOCKER_LOGIN), 1)
		@echo "Already login to DockerHub"
else
		@docker login -u $(DOCKER_USERNAME) -p $(DOCKER_PASSWORD)
endif

build:
	docker build  \
	--build-arg POSTFIX_VERSION=$(POSTFIX_VERSION) \
	--build-arg DOVECOT_VERSION=$(DOVECOT_VERSION) \
	--build-arg VCS_REF=`git rev-parse --short HEAD` \
	--build-arg DEBUG=$(DEBUG) \
	-t $(NAME):$(VERSION) --rm .

generate_users:
	docker run --rm \
	-e MAIL_USER=user1@localhost.localdomain \
	-e MAIL_PASS=mypassword \
	$(NAME):$(VERSION) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' > test/config/postfix-accounts.cf

	docker run --rm \
	-e MAIL_USER=user2@otherdomain.tld \
	-e MAIL_PASS=mypassword \
	$(NAME):$(VERSION) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' >> test/config/postfix-accounts.cf

run:
	@if ! docker images $(NAME) | awk '{ print $$2 }' | grep -q -F $(VERSION); then echo "$(NAME) version $(VERSION) is not yet built. Please run 'make build'"; false; fi
	docker run -d --name mail \
		-e DEBUG=$(DEBUG) \
		-e ENABLE_MANAGESIEVE=1 \
		-e SA_TAG=1.0 \
		-e SA_TAG2=2.0 \
		-e SA_KILL=3.0 \
		-e SASL_PASSWD="external-domain.com username:password" \
		-e PERMIT_DOCKER=host \
		-v "`pwd`/test/config":/tmp/config \
		-v "`pwd`/test/":/tmp/test \
		-h mail.my-domain.com $(NAME):$(VERSION) /sbin/my_init

	sleep 15

	docker run -d --name mail_pop3 \
		-e DEBUG=$(DEBUG) \
		-e DISABLE_CLAMAV=1 \
		-e ENABLE_POP3=1 \
		-e SSL_TYPE=certbot \
		-v "`pwd`/test/config":/tmp/config \
		-v "`pwd`/test/":/tmp/test \
		-v "`pwd`/test/certbot":/etc/certbot/live \
		-h mail.my-domain.com $(NAME):$(VERSION) /sbin/my_init

	sleep 10

	docker run -d --name mail_smtponly \
		-e DEBUG=$(DEBUG) \
		-e DISABLE_CLAMAV=1 \
		-e SMTP_ONLY=1 \
		-v "`pwd`/test/config":/tmp/config \
		-v "`pwd`/test/":/tmp/test \
		-h mail.my-domain.com $(NAME):$(VERSION) /sbin/my_init

	sleep 10

	docker run -d --name mail_fail2ban \
		-e DEBUG=$(DEBUG) \
		-e DISABLE_CLAMAV=1 \
		-e ENABLE_FAIL2BAN=1 \
		--cap-add=NET_ADMIN \
		-v "`pwd`/test/config":/tmp/config \
		-v "`pwd`/test/":/tmp/test \
		-h mail.my-domain.com $(NAME):$(VERSION) /sbin/my_init

	sleep 10

	docker run -d --name mail_disabled_amavis \
		-e DEBUG=$(DEBUG) \
		-e DISABLE_CLAMAV=1 \
		-e DISABLE_AMAVIS=1 \
		-v "`pwd`/test/config":/tmp/config \
		-v "`pwd`/test/":/tmp/test \
		-h mail.my-domain.com $(NAME):$(VERSION) /sbin/my_init

	sleep 10

	docker run -d --name mail_disabled_spamassassin \
		-e DEBUG=$(DEBUG) \
		-e DISABLE_CLAMAV=1 \
		-e DISABLE_SPAMASSASSIN=1 \
		-v "`pwd`/test/config":/tmp/config \
		-v "`pwd`/test/":/tmp/test \
		-h mail.my-domain.com $(NAME):$(VERSION) /sbin/my_init

	sleep 10

	docker run -d --name mail_disabled_clamav \
		-e DEBUG=$(DEBUG) \
		-e DISABLE_CLAMAV=1 \
		-v "`pwd`/test/config":/tmp/config \
		-v "`pwd`/test/":/tmp/test \
		-h mail.my-domain.com $(NAME):$(VERSION) /sbin/my_init

	sleep 15

fixtures:
	# Setup sieve & create filtering folder (INBOX/spam)
	docker cp "`pwd`/test/config/sieve/dovecot.sieve" mail:/var/mail/localhost.localdomain/user1/.dovecot.sieve
	docker exec mail /bin/sh -c "maildirmake.dovecot /var/mail/localhost.localdomain/user1/.INBOX.spam"
	docker exec mail /bin/sh -c "chown 5000:5000 -R /var/mail/localhost.localdomain/user1/.INBOX.spam"
	# Sending test mails
	sleep 10
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/amavis-spam.txt"
	sleep 2
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/amavis-virus.txt"
	sleep 2
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/existing-alias-external.txt"
	sleep 2
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/existing-alias-local.txt"
	sleep 2
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/existing-user.txt"
	sleep 2
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/existing-user-and-cc-local-alias.txt"
	sleep 2
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/existing-regexp-alias-external.txt"
	sleep 2
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/existing-regexp-alias-local.txt"
	sleep 2
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/existing-catchall-local.txt"
	sleep 2
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/sieve-spam-folder.txt"
	sleep 2
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/non-existing-user.txt"
	# Wait for mails to be analyzed
	sleep 10

test:
	./bats/bin/bats test/tests.bats

clean:
	docker stop mail mail_pop3 mail_smtponly mail_fail2ban mail_disabled_amavis mail_disabled_spamassassin mail_disabled_clamav 2> /dev/null || true
	docker rm mail mail_pop3 mail_smtponly mail_fail2ban mail_disabled_amavis mail_disabled_spamassassin mail_disabled_clamav 2> /dev/null || true
	docker images | grep "<none>" | awk '{print$3 }' | xargs docker rmi 2> /dev/null || true

publish: docker_login run test clean
	docker push $(NAME)

tag_latest:
	docker tag $(NAME):$(VERSION) $(NAME):latest

release: docker_login run fixtures test clean tag_latest
	docker push $(NAME)

clean_images: clean
	docker rmi $(NAME):latest $(NAME):$(VERSION) 2> /dev/null || true
	docker logout 


