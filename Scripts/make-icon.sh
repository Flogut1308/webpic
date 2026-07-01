#!/bin/bash
set -euo pipefail
# Render the app icon and assemble Resources/AppIcon.icns (committed to the repo so bundle.sh
# doesn't need to re-render on every build). Re-run this only when the icon design changes.
cd "$(dirname "$0")/.."
mkdir -p dist Resources
SRC="dist/icon_1024.png"
swift Scripts/make-icon.swift "$SRC"

SET="dist/AppIcon.iconset"
rm -rf "$SET"; mkdir -p "$SET"
gen() { sips -z "$1" "$1" "$SRC" --out "$SET/$2" >/dev/null; }
gen 16   icon_16x16.png
gen 32   icon_16x16@2x.png
gen 32   icon_32x32.png
gen 64   icon_32x32@2x.png
gen 128  icon_128x128.png
gen 256  icon_128x128@2x.png
gen 256  icon_256x256.png
gen 512  icon_256x256@2x.png
gen 512  icon_512x512.png
cp "$SRC" "$SET/icon_512x512@2x.png"

iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "wrote Resources/AppIcon.icns"
