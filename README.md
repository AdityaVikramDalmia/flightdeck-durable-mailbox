# durable-mailbox

A local filesystem message queue for shell scripts. Send named recipients JSON messages, drain bounded batches, retain history, and explicitly acknowledge questions. It makes no network or model calls.

Requires Bash 3.2+, jq 1.6+, and standard macOS/Linux command-line utilities. `make` runs the tests; Git is not a runtime dependency. Keep `bin/` and `lib/` together. From a checkout:

```bash
export PATH="$PWD/bin:$PATH"
export MAILBOX_DIR="$PWD/.mailbox-data"
mailbox send worker7 ask 'Can release v2 proceed?' --from builder
mailbox drain worker7 --format json
mailbox asks worker7
# Copy the id printed above:
# mailbox ack worker7 MESSAGE_ID --from reviewer
mailbox history worker7
make test
```

Or specify `mailbox --dir '/path with spaces/messages' ...` on each call. Recipients are literal: `worker7` never redirects to `worker`. Run `bash examples/roundtrip.sh` for an isolated, complete acknowledgment example.

Sends publish a complete file through a same-filesystem rename. Drains serialize per recipient and fail on lock timeout. A drain retains every emitted body under `cur/`; output and consumption are separate operations, so interruption can cause a duplicate. The application must decide whether processing succeeded. There is no exactly-once processing guarantee and no fsync/power-loss guarantee.

See [documentation](docs/README.md) for storage, limits, failure handling, and recovery. [Provenance](PROVENANCE.md) records the source revision and deliberate changes. No license is included; licensing must be settled before wider distribution.
