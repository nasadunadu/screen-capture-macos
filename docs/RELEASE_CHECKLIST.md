# Release checklist

Screen Capture is an independently maintained personal open-source project distributed directly to users rather than through the Mac App Store. A release is complete only when the source, archive, signed artifact, notarization result, and manual smoke test all refer to the same version.

## Automated gates

- The public repository has an explicit license, community files, and passing CI.
- The repository is clean and the release commit is identified.
- `plutil -lint` succeeds for `Info.plist` and `PrivacyInfo.xcprivacy`.
- The complete unit test suite passes with code signing disabled.
- Xcode static analysis succeeds for the application target.
- A generic macOS Release build succeeds for both `arm64` and `x86_64`.
- The final executable contains both architectures when Intel Macs are supported.
- `codesign --verify --deep --strict --verbose=2` succeeds.
- The release entitlements do not contain `com.apple.security.get-task-allow`.
- `spctl --assess --type execute --verbose=4` accepts the stapled app.
- The final DMG is notarized, stapled, and accepted by Gatekeeper.
- The DMG opens with `ScreenCapture.app` and an `Applications` shortcut at its root.
- The DMG and fallback ZIP each match their published SHA-256 checksum.

## Manual compatibility matrix

Test the actual archived Release build outside Xcode and without a debugger.

| Area | Required coverage |
| --- | --- |
| Hardware | Apple silicon; Intel while universal binaries are published |
| macOS | Oldest supported macOS 14; maintainer's current macOS; latest available macOS |
| Displays | Retina and non-Retina; one display; mixed-scale multi-display |
| Permission | Fresh install denied, grant and retry, revoked permission, app relaunch |
| Capture | Region, resize/move region, window, full screen, previous area, preset, delay |
| Annotation | Every visible tool on first drag, colors, line widths, undo, Save As, Escape |
| Long capture | Text page, image-heavy page, sticky header, slow and fast wheel scrolling |
| Export | Clipboard, PNG, JPEG, save-only, save-and-copy, unavailable destination |
| Lifecycle | Silent launch, menu-bar Settings, launch at login, quit and relaunch |

For long capture, confirm native pixel width, no duplicated or missing seams, no guide overlays, bounded memory growth, responsive cancellation, and a useful error when the safety limit is reached.

## Direct-distribution signing and notarization

1. In Xcode, archive with the generic macOS destination and keep Hardened Runtime and a secure timestamp enabled.
2. Upload the archive with Xcode Organizer or `scripts/release/notarize-archive.sh`, wait for an accepted result, and export the notarized app.
3. Re-run strict code-signature, stapler, and Gatekeeper assessment on the exported app.
4. Install a valid local **Developer ID Application** certificate and private key controlled by the project maintainer. A cloud-managed export alone cannot locally sign the custom DMG; the team's Account Holder must create the traditional certificate or export its identity securely to the release Mac.
5. Package the stapled app as a drag-and-drop DMG and fallback ZIP, sign, notarize, and staple the DMG, calculate both SHA-256 checksums, and test the downloaded DMG on a clean Mac.

An Apple Development-signed build, an ad-hoc build, or an artifact rejected by Gatekeeper is not a release artifact.

## GitHub handoff

- Review `.gitignore`, repository contents, secrets, personal paths, logs, crash reports, screenshots, DerivedData, and build products before upload.
- Add release comparison links after the final GitHub owner and repository name are known.
- Replace the development bundle identifier with a stable reverse-DNS identifier controlled by the release owner.
- Confirm that the application name and icon artwork are approved for public distribution.
- Confirm the intended public license with the individual project owner.
- Confirm the default branch contains the complete source and requires the CI status check.
- Publish release notes that list the supported macOS versions, permissions, known limits, checksum, and rollback version.
- Use `docs/RELEASE_NOTES_TEMPLATE.md` for the first GitHub Release.
- Never push, create a release, or change repository visibility without explicit authorization for that action.

## Rollback

Keep the previous notarized artifact and its checksum. Roll back by replacing the app bundle with that artifact; preferences remain in `UserDefaults`, and saved screenshots are not removed.
