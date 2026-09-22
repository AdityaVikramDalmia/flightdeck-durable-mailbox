#!/usr/bin/env bash
# Deprecated reference example for new Claude Code integrations (2026-09-22).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STORE="$(mktemp -d "${TMPDIR:-/tmp}/mailbox-example.XXXXXXXX")"
trap 'rm -rf "$STORE"' EXIT
export MAILBOX_DIR="$STORE/messages"
published="$("$ROOT/bin/mailbox" send reviewer ask 'Approve version 2?' --from builder)"
"$ROOT/bin/mailbox" drain reviewer --format json
"$ROOT/bin/mailbox" asks reviewer
"$ROOT/bin/mailbox" ack reviewer "${published##*/}" --from reviewer
"$ROOT/bin/mailbox" history reviewer
