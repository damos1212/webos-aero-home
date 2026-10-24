#!/bin/sh
# install-inputhook.sh [install|uninstall]
# Makes the remote's HOME button open the home directly (LG's Home never shows).
# Uses only the *hook* from LG Input Hook v1.4.0 by Simon34545 (BSD licence,
# https://github.com/Simon34545/lginputhook), downloaded from its official release and
# checksum-verified. We do NOT install the full app: its settings web server (port 1842)
# can read/write any file as root for anything on the TV/network that talks to it.
set -e
. "$(dirname "$0")/common.sh"
URL=https://github.com/Simon34545/lginputhook/releases/download/v1.4.0/org.webosbrew.inputhook_1.4.0_all.ipk
SHA=5dc3dff1fadd5da30af6f60b237282564491e62d502f2beaeca32c9febf0ecfb
HOME_KEY=${HOME_KEY:-773}    # HOME on the Magic Remote MR21; see README if yours differs
case "${1:-install}" in
install)
  TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
  echo "downloading LG Input Hook v1.4.0 ..."
  curl -fsSL -o "$TMP/ih.ipk" "$URL"
  echo "$SHA  $TMP/ih.ipk" | sha256sum -c - >/dev/null || { echo "checksum mismatch, aborting" >&2; exit 1; }
  python3 - "$TMP/ih.ipk" "$TMP/out" <<'PY'
import sys, io, os, tarfile
ipk, out = sys.argv[1], sys.argv[2]
data = open(ipk, 'rb').read(); assert data[:8] == b'!<arch>\n'
i = 8
while i < len(data):
    name = data[i:i+16].decode().strip().rstrip('/'); size = int(data[i+48:i+58]); i += 60
    if name.startswith('data.tar'):
        tf = tarfile.open(fileobj=io.BytesIO(data[i:i+size]))
        for m in tf.getmembers():
            if m.isfile() and '/inputhook/' in m.name:
                dst = os.path.join(out, m.name.split('/inputhook/', 1)[1])
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                open(dst, 'wb').write(tf.extractfile(m).read())
    i += size + (size & 1)
PY
  # webOS 6+ ships libcrypt.so.1 on some firmwares, .so.2 on newer ones: pick the matching build
  if tv "test -e /usr/lib/libcrypt.so.2"; then LIB=libcrypt2; else LIB=libcrypt1; fi
  tv "mkdir -p /var/lib/aero-home/inputhook /home/root/.config/lginputhook"
  for f in ezinject hookfactory.php lginput-hook.php; do tv_put "$TMP/out/$f" /var/lib/aero-home/inputhook/$f; done
  tv_put "$TMP/out/$LIB/libphp.so" /var/lib/aero-home/inputhook/libphp.so
  tv_put "$ROOT/tv/inputhook-start.sh" /var/lib/aero-home/inputhook-start.sh
  tv "sh -s" <<R
chmod 755 /var/lib/aero-home/inputhook/ezinject /var/lib/aero-home/inputhook-start.sh
echo '{"$HOME_KEY":{"action":"launch","id":"$APP_ID"}}' > /home/root/.config/lginputhook/keybinds.json
ln -sf /var/lib/aero-home/inputhook-start.sh /var/lib/webosbrew/init.d/45-inputhook
/var/lib/aero-home/inputhook-start.sh
tail -2 /tmp/aero-home-inputhook.log
R
  echo "HOME now opens $APP_ID (active now and at every boot)" ;;
uninstall)
  tv "sh -s" <<'R'
echo '{}' > /home/root/.config/lginputhook/keybinds.json
rm -f /var/lib/webosbrew/init.d/45-inputhook
rm -rf /var/lib/aero-home/inputhook /var/lib/aero-home/inputhook-start.sh
R
  echo "HOME is back to LG's Home now; reboot the TV to fully detach the hook" ;;
*) echo "usage: $0 [install|uninstall]"; exit 1 ;;
esac
