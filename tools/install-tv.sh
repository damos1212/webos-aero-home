#!/bin/sh
# install-tv.sh [install|uninstall]
# Puts the TV-side helpers in /var/lib/aero-home and enables them at boot via Homebrew
# Channel's startup scripts (/var/lib/webosbrew/init.d):
#   40-lg-blocklist : blocks LG ad/telemetry domains (in-RAM hosts file, nothing on the system partition)
#   55-aero-home    : launches the home at boot and replaces LG's Home whenever it appears
# Nothing on the TV's system partition is touched; uninstall removes everything.
set -e
. "$(dirname "$0")/common.sh"
case "${1:-install}" in
install)
  tv "mkdir -p /var/lib/aero-home"
  tv_put "$ROOT/tv/lg-blocklist.sh" /var/lib/aero-home/lg-blocklist.sh
  tv_put "$ROOT/tv/home-watcher.sh" /var/lib/aero-home/home-watcher.sh
  tv "sh -s" <<R
chmod 755 /var/lib/aero-home/*.sh
ln -sf /var/lib/aero-home/lg-blocklist.sh /var/lib/webosbrew/init.d/40-lg-blocklist
printf '#!/bin/sh\nexec /var/lib/aero-home/home-watcher.sh $APP_ID\n' > /var/lib/webosbrew/init.d/55-aero-home
chmod 755 /var/lib/webosbrew/init.d/55-aero-home
/var/lib/aero-home/lg-blocklist.sh --apply
/var/lib/aero-home/home-watcher.sh $APP_ID
ls -la /var/lib/webosbrew/init.d/
R
  echo "installed: blocklist + home watcher (active now and at every boot)" ;;
uninstall)
  tv "sh -s" <<'R'
rm -f /var/lib/webosbrew/init.d/40-lg-blocklist /var/lib/webosbrew/init.d/55-aero-home
[ -x /var/lib/aero-home/lg-blocklist.sh ] && /var/lib/aero-home/lg-blocklist.sh --remove
[ -f /tmp/aero-home-watcher.pid ] && kill -- -$(cat /tmp/aero-home-watcher.pid) 2>/dev/null
rm -f /var/lib/aero-home/lg-blocklist.sh /var/lib/aero-home/home-watcher.sh
R
  echo "uninstalled blocklist + watcher" ;;
*) echo "usage: $0 [install|uninstall]"; exit 1 ;;
esac
