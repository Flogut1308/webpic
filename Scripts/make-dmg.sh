#!/bin/bash
set -euo pipefail
# Build an unsigned WebPic.dmg from dist/WebPic.app (run Scripts/bundle.sh first).
APP="dist/WebPic.app"
[ -d "$APP" ] || { echo "Build the app first: bash Scripts/bundle.sh release"; exit 1; }
STAGING="dist/dmg-staging"
DMG="dist/WebPic.dmg"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "WebPic" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"
echo "Built $DMG"
