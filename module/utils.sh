#!/system/bin/sh

. "$MODDIR/config"
NM_BIN=/data/adb/modules/nomount/bin/nm
NM_BIN_UPDATE=/data/adb/modules_update/nomount/bin/nm

check_nomount() {
	if "$NM_BIN" version >/dev/null 2>&1; then
		return 0
	fi
	if "$NM_BIN_UPDATE" version >/dev/null 2>&1; then
		NM_BIN=$NM_BIN_UPDATE
		return 0
	fi
	return 1
}

ch_desc() {
	local d
  d=$(printf '%s' "$1" | tr '\r\n' '  ' | sed 's/[\\&|]/\\&/g')
	sed -i "s|^description=.*|description=${d}|" "$MODDIR/module.prop"
}

ch_desc_err() {
	ch_desc "[⚠️ Needs reflash] '${1}'"
  echo "ERROR: ${1}" >&2
}

pmex() {
	OP=$(pm "$@" 2>&1 </dev/null)
	RET=$?
	echo "$OP"
	return $RET
}

get_app_version() {
	VERSION=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 versionName=) VERSION="${VERSION#*=}"
	echo "$VERSION"
}

get_basepath() {
	BASEPATH=$(pmex path "$PKG_NAME")
	SVCL=$?

	[ $SVCL = 0 ] && BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
	echo "$BASEPATH"
	return $SVCL
}

remove_current_nm_rule() {
  "$NM_BIN" rule list 2>/dev/null | grep -F "/${MODDIR##*/}/base-rvmm.apk" | while IFS= read -r line; do
		src=${line%% -> *} # nm rule has a pattern like this: RealFile -> MountedFile
		[ -n "$src" ] && "$NM_BIN" rule del "$src"
	done
	am force-stop "$PKG_NAME" || :
}

get_mounts() {
  "$NM_BIN" rule list 2>/dev/null | grep -F "/${MODDIR##*/}/base-rvmm.apk" || :
}

mount_rv() {
	if [ ! -d "${1}/lib" ]; then
		ch_desc_err "Your installation got broken. Try reflash the module."
		return 1
	fi
	VERSION=$(get_app_version)
	if [ "$VERSION" != "$PKG_VER" ] && [ "$VERSION" ]; then
		ch_desc_err "Version mismatch (installed:$VERSION, module:$PKG_VER)"
		return 1
	fi
	remove_current_nm_rule
	if ! OP=$("$NM_BIN" rule add "${1}/base.apk" "$MODDIR/base-rvmm.apk" 2>&1); then
		ch_desc_err "NoMount rule add failed: '$OP'"
		return 1
	fi
	am force-stop "$PKG_NAME"
	cp -f "$MODDIR/module.prop.orig" "$MODDIR/module.prop"
	return 0
}

mount_rv_now() {
	if ! BASEPATH=$(get_basepath); then
		ch_desc_err "App not installed: '$BASEPATH'"
		return 1
	fi
	mount_rv "$BASEPATH"
}
