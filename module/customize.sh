#!/system/bin/sh

MODDIR="$MODPATH"
. "$MODPATH/utils.sh"

# root impl check
if [ -z "$KSU" ] && [ -z "$APATCH" ]; then
    abort "ABORTING: NoMount does NOT support Magisk, so neither does this module!"
fi

# checks for nomount, see utils.sh
check_nomount || abort "ERROR: Your kernel does NOT integrated NoMount or you haven't installed NoMount module!"
ui_print "[*] NoMount driver responded correctly, continuing..."

# copy the old post-mount.sh script (which was used to debloat the system's youtube)
# from old folder to new folder, as I do NOT want to make a permanent debloat script
#
# i choose post-mount cuz interrupting while NM is mounting isn't a great idea
# this module doesn't support Magisk anyways
OLD_DEBLOAT_SCRIPT=/data/adb/modules/${MODPATH##*/}/post-mount.sh
[ -f "$OLD_DEBLOAT_SCRIPT" ] && cp -af "$OLD_DEBLOAT_SCRIPT" "$MODPATH/"

ui_print ""
if [ -n "$MODULE_ARCH" ] && [ "$MODULE_ARCH" != "$ARCH" ]; then
	abort "ERROR: Wrong / Unsupported arch
Your device: $ARCH
Module: $MODULE_ARCH"
fi
if [ "$ARCH" = "arm" ]; then
	ARCH_LIB=armeabi-v7a
elif [ "$ARCH" = "arm64" ]; then
	ARCH_LIB=arm64-v8a
elif [ "$ARCH" = "x86" ]; then
	ARCH_LIB=x86
elif [ "$ARCH" = "x64" ]; then
	ARCH_LIB=x86_64
else abort "ERROR: unreachable: ${ARCH}"; fi

# check utils.sh
remove_current_nm_rule

IS_SYSTEM_APP=false
UPDATED_SYSTEM_APP=false
if ! OP=$(dumpsys package "$PKG_NAME") || [ -z "$OP" ]; then
	if pmex install-existing "$PKG_NAME" >/dev/null 2>&1; then
		pmex uninstall-system-updates "$PKG_NAME" >/dev/null 2>&1
		IS_SYSTEM_APP=true
	fi
else
	PKG_FLAGS=$(echo "$OP" | grep -m1 pkgFlags)
	if echo "$PKG_FLAGS" | grep -Fq ' SYSTEM '; then
		IS_SYSTEM_APP=true
		if echo "$PKG_FLAGS" | grep -Fq ' UPDATED_SYSTEM_APP '; then
			UPDATED_SYSTEM_APP=true
			ui_print "* $PKG_NAME is an updated system app"
		else
			ui_print "* $PKG_NAME is a system app"
		fi
	fi
fi

INS=true
if BASEPATH=$(get_basepath); then
	VERSION=$(get_app_version)
	if [ "$VERSION" ] && [ "$VERSION" = "$PKG_VER" ]; then
		ui_print "* $PKG_NAME is up-to-date ($VERSION)"
		INS=false
	elif [ ! -f "$MODPATH/stock/base.apk" ]; then
		ui_print "ERROR: Version mismatch
			installed: '$VERSION'
			module:    '$PKG_VER'"
		abort
	fi
fi

### pm verifier shit
pm_verifier_off() {
	VERIF1=$(settings get global verifier_verify_adb_installs)
	VERIF2=$(settings get global package_verifier_enable)
	settings put global verifier_verify_adb_installs 0
	settings put global package_verifier_enable 0
}

pm_verifier_restore() {
	settings put global verifier_verify_adb_installs "$VERIF1"
	settings put global package_verifier_enable "$VERIF2"
}
###

# return code:
  # 0: ok
  # 1: normal error
  # 2: conflict (downgrade/incompatible/duplicate)
pm_install_attempt() {
  local sz ses apki apksz out
	sz=$(stat -c "%s" "$MODPATH"/stock/*.apk | awk '{sum += $0} END {print sum}')
	if ! ses=$(pmex install-create --user 0 -i com.android.vending -r -S "$sz"); then
		ui_print "ERROR: install-create failed"
		INSTALL_ERR="$ses"
		return 1
	fi
  ses=${ses#*[} ses=${ses%]*}

	for apki in "$MODPATH"/stock/*.apk; do
		apksz=$(stat -c "%s" "$apki")
		if ! out=$(pm install-write -S "$apksz" "$ses" "$(basename "$apki")" - < "$apki" 2>&1); then
			pmex install-abandon "$ses" >/dev/null 2>&1
			ui_print "ERROR: install-write failed"
			INSTALL_ERR="$out"
			return 1
		fi
	done

	if out=$(pmex install-commit "$ses"); then
		return 0
	fi
  pmex install-abandon "$ses" >/dev/null 2>&1
	ui_print "$out"
	if echo "$out" | grep -q -e INSTALL_FAILED_VERSION_DOWNGRADE -e INSTALL_FAILED_UPDATE_INCOMPATIBLE -e INSTALL_FAILED_DUPLICATE; then
		return 2
	fi
	ui_print "ERROR: pm install failed"
	INSTALL_ERR="$out"
	return 1
}

# code 36: needs reboot and reflash
debloat_system_app() {
	if ! BASEPATH=$(get_basepath); then
		INSTALL_ERR="ERROR: basepath failed."
		return 1
	fi
	ui_print "* Creating script to debloat $BASEPATH"
  printf '%s\n' \
  '#!/system/bin/sh' \
  "/data/adb/modules/nomount/bin/nm rule add --whiteout \"$BASEPATH\"" \
  >"$MODPATH/post-mount.sh"
	chmod +x "$MODPATH/post-mount.sh"
	ui_print "* Created the post-mount script."
	return 36
}

pm_resolve_conflict() {
	local out
	if [ "$UPDATED_SYSTEM_APP" = true ]; then
		ui_print "* Uninstalling updated system app..."
		if out=$(pmex uninstall-system-updates "$PKG_NAME" 2>&1); then
			UPDATED_SYSTEM_APP=false
		else
			ui_print "$out"
		fi
	else
		ui_print "* Uninstalling user app..."
		out=$(pmex uninstall --user 0 "$PKG_NAME") || ui_print "$out"
	fi
	return 0
}

pm_install_with_retry() {
	local it rc
	for it in 1 2; do
		ui_print "* Updating $PKG_NAME to $PKG_VER"
		pm_install_attempt; rc=$?
		[ $rc = 0 ] && return 0
		[ $rc = 1 ] && return 1
		# rc = 2: conflict
		if [ "$IS_SYSTEM_APP" = true ] && [ "$UPDATED_SYSTEM_APP" = false ]; then
			debloat_system_app
			return $?
		fi
		if [ $it = 2 ]; then
			INSTALL_ERR="ERROR: still conflicting after uninstall."
			return 1
		fi
		pm_resolve_conflict; rc=$?
		[ $rc = 0 ] || return $rc
	done
}

pm_install_stock() {
	local rc
	INSTALL_ERR=""
	[ -f "$MODPATH/stock/base.apk" ] || {
		INSTALL_ERR="ERROR: Stock $PKG_NAME apk was not found"
		return 1
	}
	pm_verifier_off
	pm_install_with_retry; rc=$?
	pm_verifier_restore
	[ $rc = 0 ] || return $rc
	BASEPATH=$(get_basepath) || { INSTALL_ERR="ERROR: basepath failed."; return 1; }
}



# NOTE: exit 36: needs reflash, check up there :p
if [ "$INS" = true ]; then
	pm_install_stock; rc=$?
	case $rc in
		0) ;;
		36)
			rm -rf "$MODPATH/stock/"
      ui_print " "
      ui_print " "
			ui_print "* Reboot, then reflash this module, please"
      ui_print "* Reboot, then reflash this module, please"
      ui_print "* Reboot, then reflash this module, please"
      ch_desc_err "Only debloated, please reflash this module after reboot."
      sleep 5
      : >"$MODPATH/needs_reflash"
			return 0
			;;
		*) abort "$INSTALL_ERR" ;;
	esac
fi

# extract native libs
BASEPATHLIB=${BASEPATH}/lib/${ARCH}
if [ "$INS" = true ] || [ -z "$(ls -A1 "$BASEPATHLIB" 2>/dev/null)" ]; then
	ui_print "* Extracting native libs"
	mkdir -p "$BASEPATHLIB"
	rm -f "$BASEPATHLIB"/* >/dev/null 2>&1
	if op=$(unzip -o -j "$MODPATH/stock/base.apk" "lib/${ARCH_LIB}/*" -d "$BASEPATHLIB" 2>&1); then
		set_perm_recursive "${BASEPATH}/lib" 1000 1000 755 755 u:object_r:apk_data_file:s0
	else
		ui_print "ERROR: extracting native libs failed: '$op'"
	fi
fi

# set apk perm
set_perm "$MODPATH/base-rvmm-nm.apk" 1000 1000 644 u:object_r:apk_data_file:s0
cp -f "$MODPATH/module.prop" "$MODPATH/module.prop.orig" # backup before runs hotinstall

if [ "$KSU_HAS_HOT_INSTALL" = true ]; then
	export MODULE_HOT_INSTALL_REQUEST=true
	export MODULE_HOT_RUN_SCRIPT=hotinstall.sh
	ui_print "* Hot install: rule will be applied right after install"
else
	ui_print "* Creating NoMount rule for $PKG_NAME"
	if ! op=$(sh "$MODPATH/hotinstall.sh" 2>&1); then
		ui_print "ERROR: NoMount rule add failed!"
		ui_print "$op"
	fi
fi

rm -rf "$MODPATH/stock/"
ui_print "Done !"
ui_print "Welcome to RVMM-NoMount! You don't need to reboot!"

if [ "$KSU_HAS_HOT_INSTALL" != true ]; then
  ui_print " "
  ui_print "[FYI] Reboot if you want to use Action to quickly toggle on/off mount! Otherwise just use without reboot!"
fi
