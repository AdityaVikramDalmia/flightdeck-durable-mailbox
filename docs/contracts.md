# Storage and delivery contract

Each recipient has `tmp/`, `new/`, `cur/`, `corrupt/`, and `acted/` beneath the explicitly selected directory. New directories/files inherit a restrictive `077` umask. Use a trusted local filesystem controlled by one OS account. This is an advisory protocol among cooperating processes, not a security boundary against another process that edits the files. Recipient and state-directory symlinks are refused; all ancestor paths and existing message files remain the operator's responsibility. Network filesystems and shared cross-host operation are unsupported.

A sender stages a complete JSON object under `tmp/`, then renames it into `new/`. Existing publication/archive/quarantine destinations are never replaced. A filename
collision returns a failure and requires inspection; prior retained evidence stays
intact. The path on stdout is a receipt for publication. Ordering uses lexical filename order: a timestamp, process id, and random suffix. It approximates time order; simultaneous sends, clock rollback, and Bash 3.2's one-second clock fallback do not provide strict FIFO.

A drain holds the recipient's `.drain.lock` directory while screening, printing, and moving messages into `cur/`. A contending drain waits up to `MAILBOX_LOCK_WAIT_S` seconds (default 10; accepted range 0–86400), then exits 4 without consuming messages. A malformed envelope goes into `corrupt/`; other messages continue. Dry runs acquire the same lock but leave all message files untouched.

The default batch allows 10 messages and 16000 bytes of stored JSON. The first message is always included even when it exceeds the byte budget, allowing progress. Limits accept at most nine decimal digits. These are batch limits, not a strict output-size or memory ceiling. Rendering, JSON escaping, table headers, and the open-ask reminder affect output size; the reminder can grow with outstanding asks. `--max 0` removes the count limit, `--max-bytes 0` removes the byte limit, and `--full` removes only the byte limit.

Printing succeeds before each move to `cur/`. If printing fails, the current message stays queued and drain exits 3. If printing succeeds and the process dies before the move, the next drain can emit it again. If bytes were accepted by a pipe but the downstream consumer fails, the message may already be archived. Read `history` for recovery. This is retained message history, not exactly-once delivery or a transactional acknowledgment from the consumer. There are no retries beyond subsequent drain calls and no automatic retention pruning.

`ask` messages remain open after drain until `ack` publishes a marker under `acted/`. Acknowledgment is idempotent for ordinary retries. Concurrent acknowledgments can replace each other's audit attribution; the final marker means acknowledged. The original body remains intact. `asks` validates archived envelopes and fails on corrupt content instead of reporting
that no questions remain. `history` also validates envelopes; it can emit valid
earlier rows before encountering a corrupt later row, so consumers must inspect
its exit status. `ack` requires a message-shaped `.json` identifier, a valid drained
ask, and a regular acknowledgment marker on an idempotent retry. Directories and
symlinks do not count as acknowledgments. `asks` and `peek` are observations, not
consistent snapshots against concurrent activity.

EXIT, INT, HUP, and TERM handlers release owned locks and remove unpublished staging files when Bash can run its traps. SIGKILL, machine failure, or a signal between lock creation and owner recording can leave a lock. No automatic stale-lock deletion is attempted: process-id checks and timeout-based reclamation can accidentally remove a live owner's lock.

To recover, first stop **all** producers/consumers using that storage. Inspect `.drain.lock/pid`, confirm the prior process has stopped, remove the `pid` file, and remove the empty lock directory with `rmdir`. Inspect residual `tmp/` files before discarding them; they were never published. Restart users only after recovery. Never delete a lock while callers are still running.

No command calls `fsync`. Atomic visibility from rename is not proof that storage survives power loss. Back up the complete storage directory while callers are stopped. A failed publication or failed stdout receipt may require checking `new/` and `cur/` before retrying.
