# durable-mailbox

> **Deprecated for new Claude Code integrations — 2026-09-22.** Retained as an
> Apache-2.0 public reference implementation. This is a maintainer status
> decision, not a claim that Claude
> Code replaces every capability. No ongoing feature work or support is promised.
> See the [messaging chronology and replacement boundary](docs/release/messaging.md).

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

See [documentation](docs/README.md) for storage, limits, failure handling, and recovery. [Provenance](PROVENANCE.md) records the source revision and deliberate changes. Licensed under Apache-2.0; see [LICENSE](LICENSE) and [NOTICE](NOTICE). The repository is public.

## License and maintenance

Copyright 2026 Aditya Dalmia. Licensed under [Apache-2.0](LICENSE), with
[attribution](NOTICE) and [source provenance](PROVENANCE.md). This is a public
reference implementation, deprecated for new Claude Code integrations as of 2026-09-22. See the [release preparation index](docs/release/README.md),
[contributing guide](CONTRIBUTING.md), and [security contact](SECURITY.md).
