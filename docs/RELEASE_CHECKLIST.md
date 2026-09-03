# Release checklist

Screen Capture is distributed directly to the team rather than through the Mac App Store. A release is complete only when the source, archive, signed artifact, notarization result, and manual smoke test all refer to the same version.

## Automated gates

- The repository is clean and the release commit is identified.
- `plutil -lint` succeeds for `Info.plist` and `PrivacyInfo.xcprivacy`.
- The complete unit test suite passes with code signing disabled.
- Xcode static analysis succeeds for the application target.
- A generic macOS Release build succeeds for both `arm64` and `x86_64`.
- The final executable contains both architectures when Intel Macs are supported.
- `codesign --verify --deep --strict --verbose=2` succeeds.
- The release entitlements do not contain `com.apple.security.get-task-allow`.
- `spctl --assess --type execute --verbose=4` accepts the stapled app.

## Manual compatibility matrix

Test the actual archived Release build outside Xcode and without a debugger.

| Area | Required coverage |
| --- | --- |
| Hardware | Apple silicon; Intel if the team still uses it |
| macOS | Oldest supported macOS 14; current team macOS; latest available macOS |
| Displays | Retina and non-Retina; one display; mixed-scale multi-display |
| Permission | Fresh install denied, grant and retry, revoked permission, app relaunch |
| Capture | Region, resize/move region, window, full screen, previous area, preset, delay |
| Annotation | Every visible tool on first drag, colors, line widths, undo, Save As, Escape |
| Long capture | Text page, image-heavy page, sticky header, slow and fast wheel scrolling |
| Export | Clipboard, PNG, JPEG, save-only, save-and-copy, unavailable destination |
| Lifecycle | Silent launch, menu-bar Settings, launch at login, quit and relaunch |

For long capture, confirm native pixel width, no duplicated or missing seams, no guide overlays, bounded memory growth, responsive cancellation, and a useful error when the safety limit is reached.

## Direct-distribution signing and notarization

1. Install a valid **Developer ID Application** certificate for the release team.
2. In Xcode, archive with the generic macOS destination and export using **Developer ID** distribution.
3. Keep Hardened Runtime enabled and use a secure timestamp.
4. Submit the exported archive with Xcode or `notarytool` and wait for an accepted result.
5. Staple the ticket with `xcrun stapler staple ScreenCapture.app`.
6. Re-run strict code-signature and Gatekeeper assessment on the stapled artifact.
7. Package the stapled app, calculate a SHA-256 checksum, and test the downloaded package on a clean Mac.

An Apple Development-signed build, an ad-hoc build, or an artifact rejected by Gatekeeper is not a release artifact.

## GitHub handoff

- Review `.gitignore`, repository contents, secrets, personal paths, logs, crash reports, screenshots, DerivedData, and build products before upload.
- Choose repository visibility before creation. If public distribution is approved, choose and add an explicit open-source license before publishing.
- Publish release notes that list the supported macOS versions, permissions, known limits, checksum, and rollback version.
- Start with a private team repository unless public visibility is explicitly approved.
- Never push, create a release, or change repository visibility without explicit authorization for that action.

## Rollback

Keep the previous notarized artifact and its checksum. Roll back by replacing the app bundle with that artifact; preferences remain in `UserDefaults`, and saved screenshots are not removed.
