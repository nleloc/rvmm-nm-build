#!/system/bin/sh
MODDIR="$(dirname "$(readlink -f "$0")")"
. "$MODDIR/utils.sh"

check_nomount || {
	ch_desc "⚠️ NoMount driver not responding, rule not created. Try rebooting."
	exit 1
}

mount_rv_now || exit 1

nohup cmd package compile -m speed-profile -f "$PKG_NAME" </dev/null >/dev/null 2>&1 &
