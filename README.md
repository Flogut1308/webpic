# WebPic

A native macOS app for optimizing images for the web — convert, compress, resize, generate responsive sets, and produce copy-paste `<picture>` / React / Next.js / Vue snippets.

- **Platform:** macOS 14+
- **Tech:** SwiftUI (+ AppKit interop), Swift Package; WebP via `libwebp`, AVIF/JPEG/PNG via ImageIO
- **Distribution:** downloadable DMG with a lightweight GitHub-Releases auto-update check

## Build & run

```bash
swift build            # compile
swift test             # run the WebPicCore test suite
bash Scripts/bundle.sh # assemble dist/WebPic.app  (append `release` for a release build)
open dist/WebPic.app
```

## Package a DMG

```bash
bash Scripts/bundle.sh release
bash Scripts/make-dmg.sh   # → dist/WebPic.dmg (app + Applications symlink)
```

## Installation (for downloaders)

1. Download `WebPic.dmg` from the [Releases](https://github.com/Flogut1308/webpic/releases) page and open it.
2. Drag **WebPic** onto **Applications**.
3. **First launch — the app is ad-hoc signed but not notarized** (no Apple Developer ID yet), so macOS Gatekeeper blocks it once. Bypass it:
   - **Simplest (reliable on every macOS incl. 15 Sequoia / 26 Tahoe):** run
     `xattr -dr com.apple.quarantine /Applications/WebPic.app`, then open normally.
   - **Or via UI:** double-click WebPic → dismiss the block → **System Settings → Privacy & Security** → scroll down → **"Open Anyway"** → confirm.
   - ⚠️ On macOS 15+/26 the old **right-click → Open** shortcut no longer bypasses Gatekeeper — use one of the two options above.

WebPic checks GitHub Releases on launch and, when a newer version exists, shows an in-app banner; "Installieren" opens the latest DMG download.

> **Note on signing:** builds are currently **unsigned / un-notarized**. To ship a notarized DMG later: obtain an Apple Developer account ($99/yr) + Developer ID certificate, then `codesign` the `.app`, submit the DMG with `notarytool`, and `stapler staple` it.

Docs: spec + milestone plans live under [`docs/superpowers/`](docs/superpowers/).
