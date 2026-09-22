# Messaging chronology and deprecation

**Deprecation recorded: 2026-09-22.** The maintainer has deprecated this reference
project for new Claude Code integrations. Prefer Claude Code's native messaging
for supported live-session communication. The disk-queue example remains available
for studying bounded drains, retained history, and explicit acknowledgment.

## Verified sequence

| Date | Evidence | What it establishes |
|---|---|---|
| 2026-07-25 | Private source commit `64174c6`, `bin/lane-say.sh` | A live-session bridge existed in the original rig. This bridge is not included in the extracted mailbox. |
| 2026-07-26 | Private source commit `a729b76`, `bin/mailbox.sh` | A separate disk mailbox decoupled delivery from the recipient being live or idle. |
| 2026-08-07 | [Claude Code v2.1.224](https://github.com/anthropics/claude-code/releases/tag/v2.1.224) | Anthropic released cross-session messaging. GitHub records publication at 04:00:59 UTC. |
| 2026-08-08 | Private source commit `d1df433`, messaging evaluation and runbook | The original rig adopted native live-peer transport after four successful probes; it explicitly retained durable mailbox and ledger semantics. |
| 2026-09-22 | Extraction commit `80e4945fdbb1318418a2bedfede424f91217ee75` | This standalone queue was extracted with explicit storage and synthetic tests. |
| 2026-09-22 | Current maintenance decision | The maintainer requested deprecation of all twelve reference repositories for new Claude Code integrations. |

Claude Code's earlier [agent-team preview, v2.1.32](https://github.com/anthropics/claude-code/releases/tag/v2.1.32),
was published on February 5, 2026. The July source work predates the August
cross-session release, not that February feature. No priority claim is made
about agent messaging as a general idea.

## Replacement boundary

[Native cross-session messaging](https://code.claude.com/docs/en/cross-session-messaging)
provides discovery and text delivery between supported Claude Code sessions. It
is not an assertion that this queue's retained local records, explicit asks/acks,
or non-Claude shell callers have identical native replacements. The August
adoption record kept both channels for different jobs; today's deprecation does
not rewrite that historical decision or change the original rig runtime.

No original messages, session transcripts, private configuration, or source Git
history are distributed here. The source dates are repository evidence; the
standalone implementation and this deprecation note have their actual dates.
