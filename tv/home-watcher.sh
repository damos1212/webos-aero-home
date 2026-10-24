#!/bin/sh
# home-watcher.sh [appId]  (runs on the TV, started at boot by init.d/55-aero-home)
#  - boot: launches the home as soon as the app manager accepts it
#  - whenever LG's own Home (com.webos.app.home) comes to the front, launches ours instead
# Undo: rm /var/lib/webosbrew/init.d/55-aero-home; kill -- -$(cat /tmp/aero-home-watcher.pid)
APP=${1:-tld.my.home}
PIDFILE=/tmp/aero-home-watcher.pid
LOG=/tmp/aero-home-watcher.log

# only one watcher at a time: stop a previous one (its whole process group)
if [ -f $PIDFILE ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then kill -- -"$(cat $PIDFILE)" 2>/dev/null; sleep 1; fi

setsid sh -c '
  APP="$1"; LOG="$2"
  launch() { luna-send -n 1 luna://com.webos.applicationManager/launch "{\"id\":\"$APP\"}" </dev/null 2>/dev/null; }
  # boot launch: retry until the app manager is ready (max ~60 s)
  i=0
  until launch | grep -q "\"returnValue\":true" || [ $i -ge 30 ]; do i=$((i + 1)); sleep 2; done
  echo "$(date) boot launch done ($i retries)" >> "$LOG"
  # follow foreground changes; luna-send prints one JSON object per line
  while true; do
    luna-send -i luna://com.webos.applicationManager/getForegroundAppInfo "{\"subscribe\":true}" </dev/null 2>/dev/null |
    while read -r line; do
      case "$line" in
        *\"appId\":\"com.webos.app.home\"*) echo "$(date) LG Home in front -> $APP" >> "$LOG"; launch >/dev/null ;;
      esac
    done
    sleep 3   # subscription ended (e.g. bus restart): resubscribe
  done
' aero-home-watcher "$APP" "$LOG" </dev/null >/dev/null 2>&1 &
echo $! > $PIDFILE
exit 0
