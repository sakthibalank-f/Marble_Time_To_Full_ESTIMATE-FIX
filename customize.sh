#!/system/bin/sh
SKIPUNZIP=0

ui_print "- Marble Time-To-Full Fix"

DEV="$(getprop ro.product.device)"
case "$DEV" in
  marble*) ui_print "- Device: $DEV" ;;
  *) ui_print "! Device is '$DEV', not marble. Installing anyway." ;;
esac

NODE=
for d in /sys/class/power_supply/*; do
  [ "$(cat "$d/type" 2>/dev/null)" = "Battery" ] && [ -e "$d/time_to_full_now" ] && NODE="$d/time_to_full_now" && break
done

if [ -z "$NODE" ]; then
  ui_print "! No battery time_to_full_now node found. The module will idle."
else
  RAW="$(cat "$NODE" 2>/dev/null)"
  ui_print "- Node: $NODE"
  ui_print "- Raw value right now: '$RAW'"
  ui_print "  (plug in a charger for a meaningful reading;"
  ui_print "   minutes while charging means this fix applies)"
fi

set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/ttf.conf" 0 0 0644
ui_print "- Done. Reboot to apply."
