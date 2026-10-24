#!/bin/sh
# qml-perms.sh <appId> [--remove]  (run on the TV)
# Lets a dev QML app (run by LG's qml-runner as "<appId>-<n>") use the system
# bus to launch apps, the same way LG's own QML screensaver is set up.
# Re-run after every (re)install: the installer rewrites the manifest.
set -e
APP="$1"; [ -n "$APP" ] || { echo "usage: $0 <appId> [--remove]"; exit 1; }
D=/var/luna-service2-dev
ROLE=$D/roles.d/$APP.app.json
PERM=$D/client-permissions.d/$APP.app.json
MAN=$D/manifests.d/$APP.json

if [ "$2" = "--remove" ]; then
	rm -f "$ROLE"
	echo "{\"$APP\":[\"public\"]}" > "$PERM"
	[ -f "$MAN" ] && node -e 'const fs=require("fs"),f=process.argv[1];const m=JSON.parse(fs.readFileSync(f));delete m.roleFiles;fs.writeFileSync(f,JSON.stringify(m))' "$MAN"
	ls-control scan-services >/dev/null; echo "removed extra permissions for $APP"; exit 0
fi

[ -f "$MAN" ] || { echo "$APP is not installed"; exit 1; }
echo "{\"appId\":\"$APP\",\"type\":\"regular\",\"allowedNames\":[\"$APP-*\",\"$APP\"],\"permissions\":[{\"service\":\"$APP-*\",\"outbound\":[\"*\"]},{\"service\":\"$APP\",\"outbound\":[\"*\"]}]}" > "$ROLE"
echo "{\"$APP-*\":[\"public\",\"applications\",\"applications.launch\",\"settings\"],\"$APP\":[\"public\",\"applications\",\"applications.launch\",\"settings\"]}" > "$PERM"
node -e 'const fs=require("fs"),f=process.argv[1],r=process.argv[2];const m=JSON.parse(fs.readFileSync(f));m.roleFiles=[r];fs.writeFileSync(f,JSON.stringify(m))' "$MAN" "$ROLE"
ls-control scan-services >/dev/null
echo "granted launch permissions to $APP"
