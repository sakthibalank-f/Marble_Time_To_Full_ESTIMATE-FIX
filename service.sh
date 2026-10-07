#!/system/bin/sh
# Marble Time-To-Full Fix
#
# Bind-mounts a converted copy of time_to_full_now over the real sysfs node.
# The health HAL reads this node, so it (and the framework) sees seconds.
# The real node stays readable through a file descriptor opened before mounting.

MODDIR=${0%/*}
PS=${TTF_PS:-/sys/class/power_supply}
RUN=${TTF_RUN:-/dev/ttf_fix}
F=$RUN/time_to_full_now
RAWNODE=$RUN/raw_time_to_full_now
LOG=${TTF_LOG:-/data/local/tmp/ttf_fix.log}
PIDF=$RUN/pid

MULT=60
CAP=21600
INTERVAL=5
[ -f "$MODDIR/ttf.conf" ] && . "$MODDIR/ttf.conf"

log() {
  # keep the log small
  [ -f "$LOG" ] && [ "$(wc -c < "$LOG" 2>/dev/null)" -gt 65536 ] && : > "$LOG"
  echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG"
}

# raw (minutes) + charge status -> seconds for the health HAL.
#   garbage / above CAP -> -1 (unknown: Android falls back to its own estimate)
#   0 -> 0 only when the battery is Full (AIDL contract), otherwise -1
conv() {
  case "$1" in ''|*[!0-9]*) echo -1; return ;; esac
  
  if [ "$1" -eq 0 ]; then
    [ "$2" = "Full" ] && echo 0 || echo -1
    return
  fi
  s=$(( $1 * MULT ))
  [ "$s" -gt "$CAP" ] && { echo -1; return; }
  echo "$s"
}

# Test hook: source this file with TTF_LIB=1 to get conv() only
[ -n "$TTF_LIB" ] && return 0 2>/dev/null

# one instance only
if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null; then
  exit 0
fi

# Wait for the battery node to appear (up to ~3 min) instead of waiting for
# boot_completed, so the fix is live as early as the node exists.
NODE=
STATUS=
tries=0
while [ -z "$NODE" ] && [ "$tries" -lt "${TTF_TRIES:-90}" ]; do
  for d in "$PS"/*; do
    if [ "$(cat "$d/type" 2>/dev/null)" = "Battery" ] && [ -e "$d/time_to_full_now" ]; then
      NODE="$d/time_to_full_now"
      STATUS="$d/status"
      break
    fi
  done
  [ -n "$NODE" ] || { tries=$((tries + 1)); sleep 2; }
done
if [ -z "$NODE" ]; then
  log "no battery time_to_full_now node after waiting, exiting"
  exit 0
fi

# Already shadowed (e.g. service.sh ran twice)? Don't stack mounts.
# /proc/mounts lists the resolved path, not the /sys/class symlink path.
REAL="$(readlink -f "$NODE")"
if grep -q " $REAL " /proc/mounts 2>/dev/null; then
  log "$NODE already mounted over, exiting"
  exit 0
fi

mkdir -p "$RUN"
echo $$ > "$PIDF"

# Preserve a real, reopenable view of the sysfs attribute BEFORE mounting over it.
# Using /proc/$$/fd/N for repeated reads is unsafe here because the duplicated
# file description can retain the sysfs read offset and eventually return EOF.
# A file bind-mount gives us a fresh open each poll while the original NODE is hidden.
rm -f "$RAWNODE"
touch "$RAWNODE" || {
  log "cannot create raw-node placeholder"
  exit 1
}
if ! mount -o bind "$NODE" "$RAWNODE"; then
  log "raw-node bind mount failed, exiting"
  rm -f "$RAWNODE"
  exit 1
fi

cleanup() {
  umount "$NODE" 2>/dev/null
  umount "$RAWNODE" 2>/dev/null
  rm -f "$PIDF"
}
trap 'cleanup; exit 0' INT TERM #try killing shell process immediately ^^
trap cleanup EXIT INT TERM

raw="$(cat "$RAWNODE" 2>/dev/null)"
st="$(cat "$STATUS" 2>/dev/null)"
last="$(conv "$raw" "$st")"
printf '%s\n' "$last" > "$F"
chmod 0444 "$F"
chcon --reference="$NODE" "$F" 2>/dev/null

if ! mount -o bind "$F" "$NODE"; then
  log "bind mount failed, reverting raw-node mount"
  exit 1
fi
if [ "$(cat "$NODE" 2>/dev/null)" != "$last" ]; then
  log "mount did not take effect, undoing"
  umount "$NODE"
  exit 1
fi
log "active: node=$NODE MULT=$MULT CAP=$CAP raw='$raw' -> $last"

lastraw="$raw"
while :; do
  st="$(cat "$STATUS" 2>/dev/null)"
  case "$st" in
    Charging|Full)
      raw="$(cat "$RAWNODE" 2>/dev/null)"
      v="$(conv "$raw" "$st")"
      if [ "$v" != "$last" ]; then
        printf '%s\n' "$v" > "$F"
        last="$v"
      fi
      if [ "$raw" != "$lastraw" ]; then
        log "raw='$raw' status=$st -> ${last}s"
        lastraw="$raw"
      fi
      if [ "$st" = "Charging" ]; then
        sleep "$INTERVAL"
      else
        sleep "${TTF_IDLE:-30}"
      fi
      ;;
    *)
      # Not charging: Android ignores time-to-full, so skip the raw read.
      if [ "$last" != "-1" ]; then
        printf '%s\n' -1 > "$F"
        last=-1
        lastraw=
      fi
      sleep "${TTF_IDLE:-30}"
      ;;
  esac
done