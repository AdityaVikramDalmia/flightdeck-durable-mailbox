.PHONY: test check
check:
	bash -n bin/mailbox lib/core.sh lib/lock.sh tests/test.sh
test: check
	bash tests/test.sh
