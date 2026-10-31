# Screen Capture Project Rules

## Scope

- This repository is the canonical source for the personal macOS screenshot app.
- The release scope covers normal screenshots, inline annotation, scrolling capture, export, menu-bar access, and shortcuts.
- Standalone OCR, translation, screen/audio recording, and cloud uploads remain out of scope.

## Stack

- Swift, SwiftUI, AppKit, ScreenCaptureKit, Core Graphics, Core Image, and Accelerate.
- Minimum supported system: macOS 14, including compatibility with macOS 14–26 and macOS 27. Apple Silicon (arm64) only; Intel Macs are unsupported.
- Keep the app local-first. Screenshot pixels must not leave the Mac.

## Validation

Run the complete local validation before a release or pull request:

```sh
./scripts/ci.sh
```

For a focused build, use the full Xcode developer directory without changing the workstation-wide selection:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ScreenCapture.xcodeproj \
  -scheme ScreenCapture \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Run focused tests with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ScreenCapture.xcodeproj \
  -scheme ScreenCapture \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO test
```

Direct-distribution builds must also pass `docs/RELEASE_CHECKLIST.md`. Never treat a development-signed or ad-hoc app as a public release artifact.

## Review Rules

- Preserve user screenshots and clipboard contents unless the user explicitly invokes an export action.
- Treat screen recording permission failures as a recoverable product state.
- Keep selection, annotation, and stitching logic deterministic and independently testable.
- Never commit captured images, exports, signing credentials, or local Xcode user data.
