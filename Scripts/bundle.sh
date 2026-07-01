#!/bin/bash
set -euo pipefail
CONFIG="${1:-debug}"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/WebPicApp"
APP="dist/WebPic.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WebPic"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>WebPic</string>
  <key>CFBundleDisplayName</key><string>WebPic</string>
  <key>CFBundleIdentifier</key><string>com.flogut.webpic</string>
  <key>CFBundleVersion</key><string>2.4</string>
  <key>CFBundleShortVersionString</key><string>2.4</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>WebPic</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSPhotoLibraryUsageDescription</key><string>WebPic importiert ausgewählte Fotos, um sie fürs Web zu optimieren.</string>
</dict></plist>
PLIST
# Ad-hoc sign the whole bundle. swift build only linker-signs the executable, which leaves the
# bundle signature inconsistent (Info.plist unbound) — on Apple Silicon / macOS 15+ that reads as
# "app is damaged" with no override. A proper ad-hoc signature lets a locally-built (unquarantined)
# copy launch cleanly without an Apple Developer account.
codesign --force --deep -s - "$APP"
echo "Built + ad-hoc signed $APP"
