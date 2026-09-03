# Screen Capture

A local-first, native macOS screenshot application for fast region/window/full-screen capture, inline annotation, and scrolling screenshots.

## Status

Release-candidate hardening for the first team version. Direct distribution is not complete until the archived app is Developer ID signed, notarized, stapled, and accepted by Gatekeeper.

## Product scope

- Region, window, and full-screen capture
- Retina-native pixel capture for sharp high-resolution output
- Previous-area, preset-size, and delayed capture
- Inline shapes, arrows, pen, text, and spotlight
- Undo/redo and element selection/movement
- Clipboard, PNG/JPEG file export, and Save As
- iShot-style scrolling workspace with a live left-hand viewport, borderless stitched preview on the right, and a compact floating action bar
- Fixed-size ScreenCaptureKit stream, live Vision alignment, and deterministic long-image stitching
- Native-resolution long capture with self-window exclusion, incremental memory use, and system-wide `Escape` cancellation
- Silent-launch Dock app with a persistent menu-bar status item, editable global shortcuts, and on-demand native settings

Out of scope for this milestone: screen recording, audio recording, translation, and OCR.

## Requirements

- macOS 14 or newer
- Xcode 26 or newer
- Screen Recording permission for the built app

## Build

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ScreenCapture.xcodeproj \
  -scheme ScreenCapture \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Open `ScreenCapture.xcodeproj` in Xcode, choose your development team if needed, and press `Command-R`. The app starts without opening or repeatedly restoring a dashboard window, while keeping its branded Dock icon and menu-bar status item. Screenshot actions and Settings remain available from the menu-bar icon; the first screenshot request prompts for Screen Recording permission.

## Test

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ScreenCapture.xcodeproj \
  -scheme ScreenCapture \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO test
```

The repository enables complete Swift concurrency checking. Release builds use automatic signing; a publicly downloadable app or DMG must additionally be signed with a Developer ID Application certificate and notarized by Apple.

The full automated, compatibility, signing, notarization, and rollback gates are in [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md).

## Default shortcuts

- `Command-4`: ordinary region capture
- `Command-5`: scrolling long capture selection
- `Escape`: cancel the active workflow at any point, including while a long screenshot is collecting or rendering

Every screenshot mode can be assigned by clicking its recorder field in **Settings → Capture** and pressing the desired key combination. `Command-4` and `Command-5` remain the defaults for ordinary and scrolling capture.

## Repository layout

- `ScreenCapture/App`: app lifecycle and menu bar
- `ScreenCapture/Capture`: screen capture and selection overlay
- `ScreenCapture/Annotation`: inline editor and tools
- `ScreenCapture/LongCapture`: frame collection and stitching
- `ScreenCapture/Services`: export, hotkeys, and system integrations
- `ScreenCapture/Settings`: persisted preferences
- `ScreenCaptureTests`: deterministic core tests
- `docs`: product and architecture decisions

## Maintainer

Native team utility maintained in this repository.
