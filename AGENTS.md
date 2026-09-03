# Screen Capture Project Rules

## Scope

- This repository is the canonical source for the personal macOS screenshot app.
- The first release covers normal screenshots, inline annotation, scrolling capture, export, menu-bar access, and shortcuts.
- Do not add screen recording, audio recording, translation, or OCR unless the owner expands scope.

## Stack

- Swift, SwiftUI, AppKit, ScreenCaptureKit, Core Graphics, Core Image, and Accelerate.
- Minimum supported system: macOS 14.
- Keep the app local-first. Screenshot pixels must not leave the Mac.

## Validation

Use the full Xcode developer directory without changing the workstation-wide selection:

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

## Review Rules

- Preserve user screenshots and clipboard contents unless the user explicitly invokes an export action.
- Treat screen recording permission failures as a recoverable product state.
- Keep selection, annotation, and stitching logic deterministic and independently testable.
- Never commit captured images, exports, signing credentials, or local Xcode user data.
