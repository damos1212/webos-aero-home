#!/bin/sh
# deploy.sh [appdir] [screenshot.png]
# Build the .ipk, install it on the TV, grant the QML permissions, check for QML errors,
# (re)start the app and optionally take a screenshot.
set -e
. "$(dirname "$0")/common.sh"
APPDIR=${1:-$ROOT/home/tld.my.home}; SHOT=$2
[ -f "$APPDIR/ambient.wav" ] || { echo "No ambient.wav yet: run tools/make-audio.sh first." >&2; exit 1; }
ID=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["id"])' "$APPDIR/appinfo.json")
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
python3 "$ROOT/tools/mkipk.py" "$APPDIR" "$TMP/app.ipk" >/dev/null
tv_put "$TMP/app.ipk" /tmp/deploy.ipk
tv_put "$ROOT/tools/qml-perms.sh" /var/lib/aero-home/qml-perms.sh 2>/dev/null || { tv "mkdir -p /var/lib/aero-home"; tv_put "$ROOT/tools/qml-perms.sh" /var/lib/aero-home/qml-perms.sh; }
tv_put "$ROOT/tools/qml-check.sh" /var/lib/aero-home/qml-check.sh
tv "sh -s" <<R
chmod 755 /var/lib/aero-home/*.sh
luna-send -n 1 luna://com.webos.applicationManager/closeByAppId '{"id":"$ID"}' </dev/null >/dev/null
luna-send -w 30000 -n 8 luna://com.webos.appInstallService/dev/install '{"id":"$ID","ipkUrl":"/tmp/deploy.ipk","subscribe":true}' </dev/null >/dev/null
i=0; while [ ! -f /media/developer/apps/usr/palm/applications/$ID/appinfo.json ] && [ \$i -lt 30 ]; do sleep 1; i=\$((i+1)); done; sleep 2
/var/lib/aero-home/qml-perms.sh $ID
/var/lib/aero-home/qml-check.sh $ID | grep -v ": OK" && echo "QML ERRORS ABOVE" || echo "QML check: OK"
# restart AFTER permissions: an instance started earlier (e.g. by the watcher during the
# install) has no working bus handle and HOME could not bring it back
luna-send -n 1 luna://com.webos.applicationManager/closeByAppId '{"id":"$ID"}' </dev/null >/dev/null; sleep 2
luna-send -n 1 luna://com.webos.applicationManager/launch '{"id":"$ID"}' </dev/null >/dev/null; sleep 5
luna-send -n 1 luna://com.webos.service.capture/executeOneShot '{"path":"/tmp/aero-shot.png","method":"DISPLAY","format":"PNG","width":1920,"height":1080}' </dev/null >/dev/null
R
[ -n "$SHOT" ] && scp -q $SSH_OPTS "$TV_USER@$TV_HOST:/tmp/aero-shot.png" "$SHOT" && echo "screenshot: $SHOT"
echo "deployed $ID"
