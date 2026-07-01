#!/bin/bash
set -euo pipefail
CONFIG="${1:-debug}"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/WebPicApp"
APP="dist/WebPic.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WebPic"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>WebPic</string>
  <key>CFBundleDisplayName</key><string>WebPic</string>
  <key>CFBundleIdentifier</key><string>com.flogut.webpic</string>
  <key>CFBundleVersion</key><string>2.1</string>
  <key>CFBundleShortVersionString</key><string>2.1</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>WebPic</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSPhotoLibraryUsageDescription</key><string>WebPic importiert ausgewählte Fotos, um sie fürs Web zu optimieren.</string>
</dict></plist>
PLIST
echo "Built $APP"
