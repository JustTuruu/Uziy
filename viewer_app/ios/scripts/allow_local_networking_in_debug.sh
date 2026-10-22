#!/bin/sh
# Xcode build phase "Debug-only local networking (ATS)".
#
# Info.plist carries NO App Transport Security exception, so Release/Profile builds (App Store) can only talk
# HTTPS. Debug builds talk to the local backend over plain http (http://localhost:8080 in the simulator,
# http://<Mac LAN IP>:8080 on a phone), so this adds NSAllowsLocalNetworking to the BUILT Info.plist of Debug
# builds only. If this script ever fails to run, Release is unaffected (fail-safe direction).
set -e
[ "${CONFIGURATION}" = "Debug" ] || exit 0
plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :NSAppTransportSecurity:NSAllowsLocalNetworking" "$plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$plist"
