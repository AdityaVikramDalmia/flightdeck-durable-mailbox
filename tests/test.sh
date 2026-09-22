#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
M="$ROOT/bin/mailbox"
T="$(mktemp -d "${TMPDIR:-/tmp}/mailbox-tests.XXXXXXXX")"
trap 'rm -rf "$T"' EXIT
export MAILBOX_DIR="$T/store with spaces"
unset MAILBOX_BY MAILBOX_FROM MAILBOX_LOCK_WAIT_S 2>/dev/null || :
N=0
ok() { N=$((N+1)); printf 'ok %s - %s\n' "$N" "$1"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
reject() { if "$@" >"$T/rejected.out" 2>"$T/rejected.err"; then fail "unexpected success: $*"; fi; }
count() { find "$1" -type f -name '*.json' | wc -l | tr -d ' '; }
"$M" --help >/dev/null
reject env -u MAILBOX_DIR "$M" peek
ok 'explicit storage required; help available without storage'
p="$("$M" send worker7 notice $'hello\nworld' --from producer --by run-123 urgent=true count=2 leading=007)"
jq -e '.to=="worker7" and .from=="producer" and .from_sid=="run-123" and .body=="hello\nworld" and .urgent==true and .count==2 and .leading=="007"' "$p" >/dev/null
[ "$p" = "$MAILBOX_DIR/worker7/new/$(basename "$p")" ]
ok 'literal recipients, multiline body and typed metadata round trip'
for recipient in ../escape .hidden a/b 'a b' a..b -bad _bad ''; do reject "$M" send "$recipient" notice hi; done
for meta in kind=ask body=bad id=bad from=bad ts=bad to=bad machine=bad from_sid=bad '=x' bad; do reject "$M" send good notice hi "$meta"; done
reject "$M" send good invented hi
reject "$M" send good notice ''
reject "$M" send good verdict hi
"$M" send good verdict ready receipt=https://example.test/evidence >/dev/null
ok 'traversal, reserved fields, invalid kind and empty body rejected'
"$M" drain worker7 --format json --dry-run >"$T/dry"
[ -f "$p" ] && [ "$(wc -l < "$T/dry" | tr -d ' ')" = 1 ]
"$M" drain worker7 --format json >"$T/drained"
[ ! -e "$p" ]
"$M" history worker7 >"$T/history"
cmp "$T/drained" "$T/history"
"$M" peek worker7 | grep '0 waiting' >/dev/null
ok 'dry run preserves queue; drain archives exact JSONL history'
p="$("$M" send questions ask 'Approve release?')"; id="${p##*/}"
reject "$M" ack questions "$id"
"$M" drain questions --format json >/dev/null
"$M" asks questions | grep "$id" >/dev/null
"$M" ack questions "$id" --from reviewer >/dev/null
"$M" ack questions "$id" >/dev/null
"$M" asks questions | grep 'no open asks' >/dev/null
[ -f "$MAILBOX_DIR/questions/cur/$id" ]
reject "$M" ack questions ../escape
ok 'asks survive drain, require explicit idempotent acknowledgment and keep body'
for i in 1 2 3; do "$M" send bounded notice "message $i" >/dev/null; done
"$M" drain bounded --format json --max 1 >"$T/batch" 2>/dev/null
[ "$(wc -l < "$T/batch" | tr -d ' ')" = 1 ]
"$M" drain bounded --format json --max-bytes 1 >"$T/batch" 2>/dev/null
[ "$(wc -l < "$T/batch" | tr -d ' ')" = 1 ]
[ "$(count "$MAILBOX_DIR/bounded/new")" = 1 ]
"$M" drain bounded --format json --max 0 --full >/dev/null
reject "$M" drain bounded --max 99999999999999999999999
reject "$M" drain bounded --max -1
reject "$M" drain bounded --max-bytes nope
ok 'count/byte limits retain tail; first oversized message makes progress'
p="$("$M" send corrupt notice healthy)"; d="${p%/*}"
printf '{broken\n' >"$d/000bad.json"
printf '%s\n' '{"body":"x"}' '{"body":"y"}' >"$d/001multiple.json"
printf '%s\n' '{"body":42}' >"$d/002type.json"
"$M" drain corrupt --format json >"$T/screened" 2>/dev/null
jq -e '.body=="healthy"' "$T/screened" >/dev/null
[ "$(count "$MAILBOX_DIR/corrupt/corrupt")" = 3 ]
ok 'malformed, multi-object, and wrongly typed envelopes quarantined'
pids=()
for i in $(seq 1 24); do "$M" send concurrent notice "message $i" >"$T/send.$i" & pids+=("$!"); done
for pid in "${pids[@]}"; do wait "$pid"; done
[ "$(count "$MAILBOX_DIR/concurrent/new")" = 24 ]
pids=()
for i in 1 2 3 4; do "$M" drain concurrent --format json --max 0 --full >"$T/drain.$i" & pids+=("$!"); done
for pid in "${pids[@]}"; do wait "$pid"; done
cat "$T"/drain.* >"$T/all"
jq -se 'length==24 and (map(.id)|unique|length)==24' "$T/all" >/dev/null
[ "$(count "$MAILBOX_DIR/concurrent/cur")" = 24 ]
ok '24 concurrent sends and four concurrent drains preserve unique messages'
p="$("$M" send locked notice queued)"
mkdir "$MAILBOX_DIR/locked/.drain.lock"
printf '%s\n' "$$" >"$MAILBOX_DIR/locked/.drain.lock/pid"
set +e
MAILBOX_LOCK_WAIT_S=0 "$M" drain locked --format json >"$T/locked" 2>/dev/null
rc=$?
set -e
[ "$rc" = 4 ] && [ -f "$p" ] && [ ! -s "$T/locked" ]
rm -f "$MAILBOX_DIR/locked/.drain.lock/pid"; rmdir "$MAILBOX_DIR/locked/.drain.lock"
"$M" drain locked --format json >/dev/null
ok 'contention fails closed with exit 4 and no output or consumption'
# A blocked stdout makes interruption reproducible without production test hooks.
big="$(printf '%100000s' x)"
p="$("$M" send interrupted notice "$big")"
mkfifo "$T/output.pipe"
(sleep 8) <"$T/output.pipe" & reader=$!
"$M" drain interrupted --format json >"$T/output.pipe" 2>"$T/interrupted.err" & writer=$!
for i in $(seq 1 100); do [ -d "$MAILBOX_DIR/interrupted/.drain.lock" ] && break; sleep .02; done
[ -d "$MAILBOX_DIR/interrupted/.drain.lock" ]
kill -TERM "$writer"
# Unblock its current write so Bash can execute the signal trap.
kill "$reader" 2>/dev/null || :
wait "$reader" 2>/dev/null || :
set +e; wait "$writer"; rc=$?; set -e
[ "$rc" = 143 ] && [ -f "$p" ] && [ ! -d "$MAILBOX_DIR/interrupted/.drain.lock" ]
ok 'TERM during blocked drain retains unconsumed message and releases lock'
p="$("$M" send pipe notice "$big")"
set +e
"$M" drain pipe --format json 2>"$T/pipe.err" | head -c 1 >/dev/null
rc=${PIPESTATUS[0]}
set -e
[ "$rc" = 3 ] && [ -f "$p" ]
ok 'broken output pipe returns failure and retains partially emitted message'
mkdir -p "$T/other"
ln -s "$T/other" "$MAILBOX_DIR/symlink"
reject "$M" send symlink notice unsafe
ok 'symlink recipient rejected'
# Pause the final envelope formatter after staging allocation, then interrupt send.
mkdir "$T/send-shim"
export REAL_JQ="$(command -v jq)" SEND_MARKER="$T/send-paused"
cat >"$T/send-shim/jq" <<'SHIM'
#!/usr/bin/env bash
if [ "${1:-}" = -c ] && [ "${3:-}" = id ]; then
  printf '%s\n' "$$" >"$SEND_MARKER"
  kill -STOP "$$"
fi
exec "$REAL_JQ" "$@"
SHIM
chmod +x "$T/send-shim/jq"
PATH="$T/send-shim:$PATH" "$M" send interrupted-send notice staged >"$T/send-interrupted.out" 2>"$T/send-interrupted.err" & writer=$!
for i in $(seq 1 200); do [ -s "$SEND_MARKER" ] && break; sleep .02; done
[ -s "$SEND_MARKER" ]; read -r shim <"$SEND_MARKER"
kill -TERM "$writer"; kill -CONT "$shim"
set +e; wait "$writer"; rc=$?; set -e
[ "$rc" = 143 ] && [ ! -s "$T/send-interrupted.out" ]
[ "$(find "$MAILBOX_DIR/interrupted-send/tmp" -type f | wc -l | tr -d ' ')" = 0 ]
[ "$(count "$MAILBOX_DIR/interrupted-send/new")" = 0 ]
ok 'TERM during staged send removes unpublished file and emits no receipt'
# Failed archive/quarantine moves must propagate; no success is inferred from printing.
mkdir "$T/move-shim"
printf '#!/usr/bin/env bash\nexit 1\n' >"$T/move-shim/mv"
chmod +x "$T/move-shim/mv"
p="$("$M" send move-failure notice queued)"
set +e
PATH="$T/move-shim:$PATH" "$M" drain move-failure --format json >"$T/move.out" 2>/dev/null; rc=$?
set -e
[ "$rc" = 3 ] && [ -f "$p" ]
[ ! -d "$MAILBOX_DIR/move-failure/.drain.lock" ]
printf '{broken\n' >"$MAILBOX_DIR/move-failure/new/000broken.json"
set +e
PATH="$T/move-shim:$PATH" "$M" drain move-failure --format json >/dev/null 2>"$T/quarantine.err"; rc=$?
set -e
[ "$rc" = 3 ] && [ -f "$MAILBOX_DIR/move-failure/new/000broken.json" ]
grep 'cannot verify quarantine' "$T/quarantine.err" >/dev/null
ok 'archive and quarantine move failures return exit 3 and retain source files'
reject "$M" ack questions .
p="$("$M" send ack-invalid ask 'Acknowledge safely')"; id="${p##*/}"
"$M" drain ack-invalid --format json >/dev/null
mkdir "$MAILBOX_DIR/ack-invalid/acted/$id"
reject "$M" ack ack-invalid "$id"
rmdir "$MAILBOX_DIR/ack-invalid/acted/$id"
ln -s "$T/nonexistent-marker" "$MAILBOX_DIR/ack-invalid/acted/$id"
reject "$M" ack ack-invalid "$id"
rm -f "$MAILBOX_DIR/ack-invalid/acted/$id"
"$M" ack ack-invalid "$id" >/dev/null
ok 'ack rejects non-message identifiers and non-regular acknowledgment markers'
p="$("$M" send corrupt-history ask 'preserve the question')"; id="${p##*/}"
"$M" drain corrupt-history --format json >/dev/null
printf '{broken\n' >"$MAILBOX_DIR/corrupt-history/cur/$id"
reject "$M" asks corrupt-history
reject "$M" history corrupt-history
ok 'corrupt archived messages fail asks/history instead of reporting an empty inbox'
p="$("$M" send collision notice 'new content')"; id="${p##*/}"
jq -c '.body="existing retained evidence"' "$p" >"$MAILBOX_DIR/collision/cur/$id"
cp -f "$MAILBOX_DIR/collision/cur/$id" "$T/retained"
set +e
"$M" drain collision --format json >"$T/collision.out" 2>/dev/null; rc=$?
set -e
[ "$rc" = 3 ] && [ -f "$p" ]
cmp "$T/retained" "$MAILBOX_DIR/collision/cur/$id"
[ ! -s "$T/collision.out" ]
printf '{old corrupt evidence\n' >"$MAILBOX_DIR/collision/corrupt/broken.json"
printf '{new corrupt evidence\n' >"$MAILBOX_DIR/collision/new/broken.json"
cp -f "$MAILBOX_DIR/collision/corrupt/broken.json" "$T/corrupt-retained"
set +e; "$M" drain collision --format json >/dev/null 2>/dev/null; rc=$?; set -e
[ "$rc" = 3 ] && [ -f "$MAILBOX_DIR/collision/new/broken.json" ]
cmp "$T/corrupt-retained" "$MAILBOX_DIR/collision/corrupt/broken.json"
ok 'archive and quarantine filename collisions preserve both pieces of evidence'
p="$("$M" send literal-values verdict 'Evidence retained' receipt=false note=$'123\n')"
jq -e '.receipt=="false" and .note=="123\n"' "$p" >/dev/null
"$M" drain literal-values >"$T/literal-values"
grep 'receipt: false' "$T/literal-values" >/dev/null
ok 'opaque receipt strings and newline-bearing metadata retain their exact values'
printf '1..%s\n' "$N"
