# Commands

`mailbox --help` prints the complete argument surface. Set `MAILBOX_DIR` or pass global `--dir PATH` before the command.

| Command | Result |
| --- | --- |
| `send RECIPIENT KIND BODY` | Publishes one message and prints its path |
| `drain RECIPIENT` | Prints a bounded table and archives printed messages |
| `drain RECIPIENT --format json` | Prints one JSON object per line |
| `drain RECIPIENT --dry-run` | Prints the next batch without moving files |
| `asks RECIPIENT` | Lists drained, unacknowledged questions |
| `ack RECIPIENT ID` | Marks a drained question acknowledged |
| `history RECIPIENT` | Prints archived messages as JSONL |
| `peek [RECIPIENT]` | Shows approximate pending counts |
| `path [RECIPIENT]` | Prints the selected root or recipient path |

Kinds are `ask`, `notice`, `recovery`, and `verdict`. A verdict requires `receipt=REFERENCE`; the reference is opaque and is not fetched or resolved. `--from NAME` and `--by ID` explicitly identify the sender. `MAILBOX_FROM` and `MAILBOX_BY` supply defaults, without discovering sessions elsewhere.

Additional `key=value` metadata uses identifier-shaped keys. `true` and `false` become booleans; unsigned decimal integers without leading zeros become numbers; other values remain strings, including values ending in a newline. `receipt` is
always preserved as an opaque string, even when it spells `false` or a number.
Empty values are omitted. jq represents numbers with its own numeric precision limits. Envelope keys are reserved. Bodies are command-line arguments, so OS argument-size limits apply.

Exit 0 means the command completed its stated operation. Invalid input exits 2. An incomplete drain exits 3; lock contention exits 4. Other tool/I/O failures can propagate their nonzero status. A nonzero status after mutation does not roll back prior successful messages or publication.
