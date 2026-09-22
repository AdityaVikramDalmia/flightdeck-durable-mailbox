# Portable, fail-closed advisory locking for trusted local storage.
# Interrupted owners release through the CLI EXIT trap; SIGKILL requires manual recovery.
LOCK_HELD=""
lock_acquire() {
  local path="$1" timeout="${2:-10}" start=$SECONDS
  case "$timeout" in ''|*[!0-9]*) die "lock timeout must be a non-negative integer" ;; esac
  [ "${#timeout}" -le 5 ] && [ "$timeout" -le 86400 ] || die "lock timeout must be between 0 and 86400 seconds"
  while ! mkdir "$path" 2>/dev/null; do
    if [ $((SECONDS-start)) -ge "$timeout" ]; then
      printf '%s: lock unavailable: %s; no operation performed\n' "$TOOL" "$path" >&2
      return 4
    fi
    sleep 0.05
  done
  LOCK_HELD="$path"
  printf '%s\n' "$$" > "$path/pid" || return 3
}
lock_release() {
  if [ -n "$LOCK_HELD" ]; then
    rm -f "$LOCK_HELD/pid"
    rmdir "$LOCK_HELD" || return 3
    LOCK_HELD=""
  fi
}
