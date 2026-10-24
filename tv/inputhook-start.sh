#!/bin/sh
# inputhook-start.sh: attach LG Input Hook v1.4.0 (hook only, no web UI/server)
# to lginput2 at boot, so remote remaps in
# /home/root/.config/lginputhook/keybinds.json apply (HOME -> custom home).
#
# Runs from Homebrew's /var/lib/webosbrew/init.d/45-inputhook. The hook only
# lives in lginput2's memory: nothing on the system partition is touched.
#
# Undo: rm /var/lib/webosbrew/init.d/45-inputhook   (then reboot to detach)
# Instant HOME undo without reboot: echo '{}' > /home/root/.config/lginputhook/keybinds.json

D=/var/lib/aero-home/inputhook
CONF=/home/root/.config/lginputhook/keybinds.json
LOG=/tmp/aero-home-inputhook.log

[ -x "$D/ezinject" ] && [ -f "$D/libphp.so" ] || exit 0
mkdir -p "$(dirname "$CONF")"
[ -f "$CONF" ] || echo '{}' > "$CONF"

# wait up to 20s for lginput2 at boot
i=0
while ! PID=$(pidof lginput2); do
	i=$((i + 1)); [ $i -ge 20 ] && { echo "lginput2 not running, giving up" >> $LOG; exit 0; }
	sleep 1
done

# never attach twice: the hook maps libphp.so into lginput2
if grep -q 'inputhook/libphp.so' /proc/$PID/maps 2>/dev/null; then
	echo "$(date) already attached to lginput2 pid $PID" >> $LOG
	exit 0
fi

echo "$(date) attaching to lginput2 pid $PID" >> $LOG
cd "$D" && ./ezinject "$PID" "$D/libphp.so" "$D/lginput-hook.php" lginput2 \
	> /tmp/ezinject-lginput2.log 2>&1 < /dev/null
echo "$(date) ezinject exit $?" >> $LOG
exit 0
