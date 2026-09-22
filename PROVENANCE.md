# Provenance

Extracted from source revision `494799eea3b9e7ce8686506a288c297ccf96be8d`.

- `bin/mailbox.sh`: bounded drain, checked emit/consume ordering, quarantine, open asks, acknowledgment, status and retained history.
- `bin/mailbox-test.sh`: regression scenarios informed the synthetic standalone suite.
- `bin/lib/registry.sh` and `bin/lib/fmt.sh`: date, identity, and error-helper behavior informed the small local helpers; their registry discovery was removed.
- `bin/lib/lock.sh`: advisory-lock integration informed the local locking contract; automatic stale recovery and unlocked fallback were deliberately removed.

The extracted tool uses explicit storage and literal recipient names, keeps sender identity explicit, stages messages with `mktemp`, treats verdict references as opaque metadata, screens envelope types, and fails closed on drain contention. It contains no private live state or imported historical fixtures. The standalone tests are synthetic. This file records provenance, not a license grant.
