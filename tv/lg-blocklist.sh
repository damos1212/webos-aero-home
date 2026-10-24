#!/bin/sh
# lg-blocklist.sh: block LG ad/telemetry domains on a rooted LG webOS TV.
#
# Homebrew Channel already rebuilds /etc/hosts at every boot as a copy in RAM
# (/tmp/hosts bind-mounted over /etc/hosts) to block update servers. This
# script adds a marked block of extra entries to that RAM copy. Nothing on the
# system partition is ever written, and a reboot without the hook clears it.
#
# Install (once, on the TV):
#   mkdir -p /var/lib/aero-home
#   cp lg-blocklist.sh /var/lib/aero-home/ && chmod 755 /var/lib/aero-home/lg-blocklist.sh
#   ln -sf /var/lib/aero-home/lg-blocklist.sh /var/lib/webosbrew/init.d/40-lg-blocklist
#   /var/lib/aero-home/lg-blocklist.sh            # apply now, no reboot needed
#
# Undo (one line):
#   rm -f /var/lib/webosbrew/init.d/40-lg-blocklist; /var/lib/aero-home/lg-blocklist.sh --remove
#
# Usage: lg-blocklist.sh [--apply|--remove|--status]

BEGIN='# >>> lg-blocklist (aero-home) >>>'
END='# <<< lg-blocklist (aero-home) <<<'
HOSTS=/etc/hosts

# Exact names only (hosts files have no wildcards).
# Deliberately NOT blocked: lgtvsdp.com / lgappstv.com / lge.com as a whole,
# which run the app store, sign-in and app launching.
DOMAINS='
lgsmartad.com
ad.lgsmartad.com
info.lgsmartad.com
eu.ad.lgsmartad.com
eu.info.lgsmartad.com
us.ad.lgsmartad.com
us.info.lgsmartad.com
ad.lgappstv.com
ibis.lgappstv.com
ngfts.lge.com
aic-ngfts.lge.com
eic-ngfts.lge.com
homeprv.lge.com
lgad.cjpowercast.com
alphonso.tv
api.alphonso.tv
'

# Only ever edit the RAM copy. If Homebrew didn't bind-mount it (updates
# block switched off), make our own RAM copy the same way Homebrew does.
ensure_ram_hosts() {
	if ! grep -q ' /etc/hosts ' /proc/mounts; then
		cp /etc/hosts /tmp/hosts && mount --bind /tmp/hosts /etc/hosts || {
			echo "could not make a RAM copy of /etc/hosts; not touching it" >&2
			exit 1
		}
	fi
}

strip_block() {
	# print hosts without our marked block
	awk -v b="$BEGIN" -v e="$END" '$0==b{skip=1;next} $0==e{skip=0;next} !skip' "$HOSTS"
}

do_remove() {
	grep -qF "$BEGIN" "$HOSTS" || { echo "lg-blocklist: nothing to remove"; return 0; }
	ensure_ram_hosts
	strip_block > /tmp/hosts.lgbl.$$ && cat /tmp/hosts.lgbl.$$ > "$HOSTS"
	rm -f /tmp/hosts.lgbl.$$
	echo "lg-blocklist: removed"
}

do_apply() {
	ensure_ram_hosts
	{
		strip_block
		echo "$BEGIN"
		for d in $DOMAINS; do
			echo "0.0.0.0 $d"
			echo "::      $d"
		done
		echo "$END"
	} > /tmp/hosts.lgbl.$$ && cat /tmp/hosts.lgbl.$$ > "$HOSTS"
	rm -f /tmp/hosts.lgbl.$$
	echo "lg-blocklist: $(echo $DOMAINS | wc -w) domains blocked"
}

do_status() {
	if grep -qF "$BEGIN" "$HOSTS"; then
		echo "lg-blocklist: active"
		awk -v b="$BEGIN" -v e="$END" '$0==b{on=1;next} $0==e{on=0} on && /^0\.0\.0\.0/{print "  " $2}' "$HOSTS"
	else
		echo "lg-blocklist: not active"
	fi
	[ -L /var/lib/webosbrew/init.d/40-lg-blocklist ] && echo "boot hook: installed" || echo "boot hook: not installed"
}

case "${1:---apply}" in
	--apply)  do_apply ;;
	--remove) do_remove ;;
	--status) do_status ;;
	*) echo "usage: $0 [--apply|--remove|--status]" >&2; exit 1 ;;
esac
exit 0
