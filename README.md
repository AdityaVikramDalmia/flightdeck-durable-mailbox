# durable-mailbox

A local filesystem message queue for shell scripts: send named recipients JSON messages, drain
bounded batches, retain history, and explicitly acknowledge questions. It makes no network or
model calls.

> **Status:** public Apache-2.0 reference implementation, deprecated for new Claude Code
> integrations as of 2026-09-22. Not a claim that Claude Code replaces every capability; no
> ongoing feature work or support is promised.
> See the [messaging chronology and replacement boundary](docs/release/messaging.md).

## What it does

- `mailbox send RECIPIENT KIND BODY` stages a complete JSON message and publishes it into the
  recipient's queue with a same-filesystem rename. Kinds are `ask`, `notice`, `recovery`, and `verdict`.
- `mailbox drain RECIPIENT` prints a bounded batch, as a table or JSON lines, and retains every
  printed message under `cur/`.
- `ask` messages stay open after a drain until `mailbox ack`; `asks` lists them and `history`
  prints the retained archive.

Recipients are literal: `worker7` never redirects to `worker`.

## Why it exists

Delivery should not depend on the recipient being live or idle when a message is sent, and a
question should not count as handled just because it was printed. The mailbox holds messages on
disk until a drain, keeps what was drained, and keeps questions open until an explicit acknowledgment.

## Install

Requires Bash 3.2+, jq 1.6+, and standard macOS/Linux command-line utilities. `make` runs the
tests; Git is not a runtime dependency. Keep `bin/` and `lib/` together. Run it from a checkout:

```bash
git clone https://github.com/AdityaVikramDalmia/flightdeck-durable-mailbox.git
cd flightdeck-durable-mailbox
export PATH="$PWD/bin:$PATH"
```

## Quick use

```bash
export MAILBOX_DIR="$PWD/.mailbox-data"
mailbox send worker7 ask 'Can release v2 proceed?' --from builder
mailbox drain worker7 --format json
mailbox asks worker7
# Copy the id printed above:
# mailbox ack worker7 MESSAGE_ID --from reviewer
mailbox history worker7
```

Or specify `mailbox --dir '/path with spaces/messages' ...` on each call. Run `bash examples/roundtrip.sh` for an isolated, complete acknowledgment example.
The [command reference](docs/commands.md) covers commands, message kinds, metadata, and exit codes.

## Limits

- Sends publish a complete file through a same-filesystem rename. Drains serialize per recipient
  and fail on lock timeout. A drain retains every emitted body under `cur/`; output and consumption
  are separate operations, so interruption can cause a duplicate. The application must decide
  whether processing succeeded. There is no exactly-once processing guarantee and no
  fsync/power-loss guarantee.
- This is an advisory protocol among cooperating processes on one trusted local filesystem, not a
  security boundary. Network filesystems and shared cross-host operation are unsupported, and
  stale locks are never removed automatically ([storage and delivery contract](docs/contracts.md)).

See [documentation](docs/README.md) for storage, limits, failure handling, and recovery. [Provenance](PROVENANCE.md) records the source revision and deliberate changes.

## Test

```bash
make test
```

## License and maintenance

Copyright 2026 Aditya Dalmia. Licensed under [Apache-2.0](LICENSE), with
[attribution](NOTICE) and [source provenance](PROVENANCE.md). This is a public
reference implementation, deprecated for new Claude Code integrations as of 2026-09-22. See the [release preparation index](docs/release/README.md),
[contributing guide](CONTRIBUTING.md), and [security contact](SECURITY.md).
