# Small standalone helpers; no user/session registry discovery.
die() { printf '%s: %s\n' "$TOOL" "$*" >&2; exit 2; }
mbx_warn() { printf '%s: %s\n' "$TOOL" "$*" >&2; }
mbx_utc_iso() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
mbx_utc() { date -u '+%Y-%m-%d %H:%MZ'; }
mbx_fmt_age() { printf '%ss' "$1"; }
mbx_self_sid() { printf '%s' "${MAILBOX_BY:-}"; }
mbx_norm_sid() {
  case "${1:-}" in ''|*[!A-Za-z0-9._:-]*) die 'sender id must contain only letters, digits, ., _, :, -' ;; esac
  printf '%s' "$1"
}
mbx_need_recipient() {
  case "${1:-}" in ''|[!A-Za-z0-9]*|*..*|*[!A-Za-z0-9._-]*) die 'recipient must be [A-Za-z0-9][A-Za-z0-9._-]* without ..' ;; esac
  MBX_RECIPIENT="$1"; MBX_RECIPIENT_RAW="$1"
}
mbx_dir() { printf '%s/%s' "$INBOX_DIR" "$1"; }
mbx_ensure() {
  local d; d="$(mbx_dir "$1")"
  [ ! -L "$d" ] || die 'recipient directory must not be a symlink'
  local leaf
  for leaf in tmp new cur corrupt acted; do
    [ ! -L "$d/$leaf" ] || die 'mailbox state directory must not be a symlink'
  done
  mkdir -p "$d/tmp" "$d/new" "$d/cur" "$d/corrupt" "$d/acted"
}
# Refuse collisions instead of replacing retained evidence. mv -n alone reports
# success when it skips an existing destination, so verify that source moved.
mbx_move_unique() {
  [ ! -e "$2" ] && [ ! -L "$2" ] || return 1
  mv -n "$1" "$2" || return 1
  [ ! -e "$1" ] && [ ! -L "$1" ] && { [ -e "$2" ] || [ -L "$2" ]; }
}
mbx_envelope_valid() {
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  jq -se --arg id "${1##*/}" --arg to "$2" 'length == 1 and (.[0] | type == "object" and .id == $id and .to == $to and (.body | type == "string" and length > 0) and (.kind | type == "string") and (.ts | type == "string") and (.from | type == "string"))' "$1" >/dev/null 2>&1
}
cleanup() {
  [ -z "${MBX_TMPF:-}" ] || rm -f "$MBX_TMPF"
  lock_release
}
usage() {
  cat <<'USAGE'
mailbox --dir PATH COMMAND [ARGS]

  send RECIPIENT {verdict|ask|notice|recovery} BODY [--from NAME] [--by ID] [key=value ...]
  drain RECIPIENT [--format table|json] [--dry-run] [--max N] [--max-bytes N] [--full]
  asks RECIPIENT
  ack RECIPIENT MESSAGE_ID [--from NAME] [--by ID]
  history RECIPIENT
  peek [RECIPIENT]
  path [RECIPIENT]

Storage must be explicit: --dir PATH or MAILBOX_DIR. Recipients are literal names.
Metadata values true/false and unsigned decimal integers become JSON values; others
are strings. A verdict requires receipt=REFERENCE (a caller-defined evidence link).
Drain defaults: 10 messages, 16000 source JSON bytes; the first message always fits.
0 disables a limit. --full disables only the byte limit. JSON means JSONL output.
Content remains in cur/ after drain. Output success does not prove consumer processing.
See docs/contracts.md for concurrency, interruption, and manual lock recovery.
USAGE
  exit 0
}
cmd_send() {
  case "${1:-}" in -h|--help|help) usage ;; esac
  [ $# -ge 3 ] || die 'send requires RECIPIENT KIND BODY'
  local recipient="$1" kind="$2" body="$3" from="${MAILBOX_FROM:-unknown}" by="${MAILBOX_BY:-}"
  shift 3
  mbx_need_recipient "$recipient"
  case "$kind" in verdict|ask|notice|recovery) ;; *) die "unknown kind '$kind'" ;; esac
  [ -n "$body" ] || die 'body must not be empty'
  local json k v arg receipt=''
  json="$(jq -cn --arg body "$body" '{body:$body}')"
  while [ $# -gt 0 ]; do
    case "$1" in
      --from) [ $# -ge 2 ] || die '--from needs NAME'; from="$2"; shift 2; continue ;;
      --by) [ $# -ge 2 ] || die '--by needs ID'; by="$(mbx_norm_sid "$2")"; shift 2; continue ;;
      -*) die "unknown flag '$1'" ;;
      *=*) arg="$1"; shift ;;
      *) die "expected key=value, got '$1'" ;;
    esac
    k="${arg%%=*}"; v="${arg#*=}"
    case "$k" in ''|*[!A-Za-z0-9_]*|[0-9]*) die "invalid metadata key '$k'" ;; esac
    case "$k" in id|to|kind|body|ts|machine|from|from_sid) die "reserved metadata key '$k'" ;; esac
    [ "$k" != receipt ] || receipt="$v"
    [ -n "$v" ] || continue
    json="$(jq -c --arg k "$k" --arg v "$v" '.[$k] = (if $k == "receipt" then $v elif $v == "true" then true elif $v == "false" then false elif ($v | test("\\A(0|[1-9][0-9]*)\\z")) then ($v|tonumber) else $v end)' <<<"$json")"
  done
  [ "$kind" != verdict ] || [ -n "$receipt" ] || die 'verdict requires receipt=REFERENCE'
  [ -z "$by" ] || by="$(mbx_norm_sid "$by")"
  mbx_ensure "$recipient"
  local d base stamp
  d="$(mbx_dir "$recipient")"
  stamp="${EPOCHREALTIME:-$(date -u +%s).000000}"
  stamp="${stamp/./}"; stamp="${stamp/,/}"
  MBX_TMPF="$(mktemp "$d/tmp/$stamp.$$.XXXXXXXX")"
  base="${MBX_TMPF##*/}.json"
  json="$(jq -c --arg id "$base" --arg to "$recipient" --arg kind "$kind" --arg ts "$(mbx_utc_iso)" --arg from "$from" --arg by "$by" '. + {id:$id,to:$to,kind:$kind,ts:$ts,from:$from} | if $by == "" then . else .from_sid=$by end' <<<"$json")"
  printf '%s\n' "$json" > "$MBX_TMPF"
  mbx_move_unique "$MBX_TMPF" "$d/new/$base" || { mbx_warn "publication failed or destination already exists"; return 3; }
  MBX_TMPF=''
  printf '%s\n' "$d/new/$base"
}
cmd_history() {
  [ $# -eq 1 ] || die 'history requires one recipient'
  mbx_need_recipient "$1"; mbx_ensure "$1"
  local f
  for f in "$INBOX_DIR/$1/cur/"*.json; do
    [ -f "$f" ] || continue
    mbx_envelope_valid "$f" "$1" || { mbx_warn "invalid archived envelope: ${f##*/}"; return 3; }
    jq -c . "$f" || return 3
  done
}
