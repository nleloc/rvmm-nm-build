#!/system/bin/sh
MODDIR="$(dirname "$(readlink -f "$0")")"
export MODDIR
. "$MODDIR/utils.sh"

run() {
	if ! check_nomount; then
		ch_desc "⚠️ NoMount driver not responding. Is the NoMount module installed and enabled?"
		return
	fi

  # avoid wait loop
	local tries=0
	while
		BASEPATH=$(get_basepath)
		SVCL=$?
		[ $SVCL = 20 ] && [ $tries -lt 30 ]
	do
		tries=$((tries + 1))
		sleep 2
	done

  if [ $SVCL = 20 ]; then
		ch_desc "⚠️ Package manager was not ready after 60s. Run this module's action to mount manually."
		return
	fi

	if [ $SVCL != 0 ]; then
		ch_desc_err "App not installed: '$BASEPATH'. If this was unexpected, try reflashing the module."
		return
	fi
	sleep 4

	mount_rv "$BASEPATH"
}

[ -f "$MODDIR/needs_reflash" ] || run
