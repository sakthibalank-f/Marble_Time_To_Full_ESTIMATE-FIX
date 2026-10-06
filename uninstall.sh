#!/system/bin/sh
NODE=
PS=${TTF_PS:-/sys/class/power_supply}
for d in "$PS"/*; do
  [ -e "$d/time_to_full_now" ] || continue
  REAL="$(readlink -f "$d/time_to_full_now")"
  grep -q " $REAL " /proc/mounts 2>/dev/null && NODE="$d/time_to_full_now"
done
[ -n "$NODE" ] && umount "$NODE" 2>/dev/null
RUN=${TTF_RUN:-/dev/ttf_fix}
[ -f "$RUN/pid" ] && kill "$(cat "$RUN/pid")" 2>/dev/null
umount "$RUN/raw_time_to_full_now" 2>/dev/null
rm -rf "$RUN" "${TTF_LOG:-/data/local/tmp/ttf_fix.log}"
