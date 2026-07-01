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
3. **First launch — the app is not notarized** (it isn't code-signed with an Apple Developer ID yet), so macOS Gatekeeper will warn "unidentified developer". Bypass it once:
   - **Right-click** (or Control-click) **WebPic.app → Open → Open**, or
   - run `xattr -dr com.apple.quarantine /Applications/WebPic.app`

WebPic checks GitHub Releases on launch and, when a newer version exists, shows an in-app banner; "Installieren" opens the latest DMG download.

> **Note on signing:** builds are currently **unsigned / un-notarized**. To ship a notarized DMG later: obtain an Apple Developer account ($99/yr) + Developer ID certificate, then `codesign` the `.app`, submit the DMG with `notarytool`, and `stapler staple` it.

Docs: spec + milestone plans live under [`docs/superpowers/`](docs/superpowers/).
