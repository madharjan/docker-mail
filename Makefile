
NAME = madharjan/docker-mail
VERSION = 2.11-2.2.9

.PHONY: all build gen_users run fixtures tests tag_latest release

all: build

build:
	docker build -t $(NAME):$(VERSION) --rm .

gen_users:
	docker run --rm \
	-e MAIL_USER=user1@localhost.localdomain \
	-e MAIL_PASS=mypassword \
	-t $(NAME):$(VERSION) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' > test/config/postfix-accounts.cf

	docker run --rm \
	-e MAIL_USER=user2@otherdomain.tld \
	-e MAIL_PASS=mypassword \
	-t $(NAME):$(VERSION) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' >> test/config/postfix-accounts.cf

run:
	docker run -d --name mail \
		-v "`pwd`/test/config":/tmp/config \
		-v "`pwd`/test/":/tmp/test \
		-v "`pwd`/test/certbot":/etc/certbot/live \
		-e SSL_TYPE=certbot \
		-e SASL_PASSWD="external-domain.com username:password" \
		-h mail.my-domain.com -t $(NAME):$(VERSION) /sbin/my_init

fixtures:
			# Setup sieve & create filtering folder (INBOX/spam)
			#docker cp "`pwd`/test/config/sieve/dovecot.sieve" mail:/var/mail/localhost.localdomain/user1/.dovecot.sieve
			#docker exec mail /bin/sh -c "maildirmake.dovecot /var/mail/localhost.localdomain/user1/.INBOX.spam"
			#docker exec mail /bin/sh -c "chown 5000:5000 -R /var/mail/localhost.localdomain/user1/.INBOX.spam"
			# Sending test mails
#			docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/amavis-spam.txt"
#			docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/amavis-virus.txt"
			docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/existing-alias-external.txt"
			docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/existing-alias-local.txt"
			docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/existing-user.txt"
			docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/existing-user-and-cc-local-alias.txt"
			docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/existing-regexp-alias-external.txt"
			docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/existing-regexp-alias-local.txt"
			docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/existing-catchall-local.txt"
			docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/sieve-spam-folder.txt"
			docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/emails/non-existing-user.txt"
			# Wait for mails to be analyzed
			sleep 10

tests:
	./bats/bin/bats test/tests.bats

clean:
	docker stop mail
	docker rm mail

tag_latest:
	docker tag $(NAME):$(VERSION) $(NAME):latest

release: test tag_latest
	@if ! docker images $(NAME) | awk '{ print $$2 }' | grep -q -F $(VERSION); then echo "$(NAME) version $(VERSION) is not yet built. Please run 'make build'"; false; fi
	@if ! head -n 1 Changelog.md | grep -q 'release date'; then echo 'Please note the release date in Changelog.md.' && false; fi
	docker push $(NAME)
	@echo "*** Don't forget to create a tag. git tag $(VERSION) && git push origin $(VERSION) ***"
