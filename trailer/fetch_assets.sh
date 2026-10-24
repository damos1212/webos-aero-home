#!/bin/sh
# fetch_assets.sh : copy what the trailer render needs but this repo can't ship, from YOUR TV:
#   - LG's UI font (LG Smart UI)  -> trailer/fonts/
#   - the icons of the apps on your home -> trailer/apps/<appId>/...
# Both are LG's / the app makers' property; they stay local (git-ignored).
set -e
. "$(dirname "$0")/../tools/common.sh"
T="$ROOT/trailer"
mkdir -p "$T/fonts"
scp -q $SSH_OPTS "$TV_USER@$TV_HOST:/usr/share/fonts/LG_Smart_UI-*.ttf" "$T/fonts/"
# icon paths come straight from the apps list in main.qml (devApps + "<id>/<file>")
python3 - "$ROOT/home/tld.my.home/main.qml" <<'PY' | while read -r rel; do
import re, sys
s = open(sys.argv[1]).read()
for m in re.findall(r'devApps \+ "([^"]+)"', s): print(m)
PY
  mkdir -p "$T/apps/$(dirname "$rel")"
  scp -q $SSH_OPTS "$TV_USER@$TV_HOST:/media/developer/apps/usr/palm/applications/$rel" "$T/apps/$rel" || echo "  (not found on TV: $rel)"
done
echo "trailer assets fetched"
