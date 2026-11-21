#!/system/bin/sh
MODDIR="$(dirname "$(readlink -f "$0")")"
export MODDIR
. "$MODDIR/utils.sh"

echo ""

if [ -f "$MODDIR/needs_reflash" ]; then
	echo "* The system app was only debloated. Reboot, then reflash this module, please."
	exit 0
fi

if ! check_nomount; then
	echo "ERROR: NoMount driver not responding. Is the NoMount module installed and enabled?"
	exit 1
fi

if [ -z "$(get_mounts)" ]; then
	if mount_rv_now; then
		echo "* Enabled successfully"
		echo ""
		get_mounts
	else
		echo "* Failed to enable"
	fi
else
	remove_current_nm_rule
	echo "* Disabled successfully"
	ch_desc "[DISABLED] Restored to original app until reboot. Run Action again to mount."
fi
