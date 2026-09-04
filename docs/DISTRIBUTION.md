# Direct distribution

This personal open-source project distributes the macOS app outside the Mac App Store. Source availability and binary release readiness are separate gates: a source commit may be public while a downloadable app remains a prerelease.

## Release inputs

- a clean commit on the release branch;
- an explicit semantic version and matching changelog entry;
- the complete automated and manual release checklist;
- a valid **Developer ID Application** identity;
- an Xcode notary keychain profile created without storing credentials in this repository.

## 1. Validate source

```sh
./scripts/release/preflight.sh
```

The preflight runs the full test suite, static analysis, property-list validation, and a universal unsigned Release build. It does not replace real UI, permission, multi-display, or oldest-macOS testing.

## 2. Archive and export with Developer ID

1. Open `ScreenCapture.xcodeproj` in Xcode.
2. Select **Any Mac (Apple Silicon, Intel)**.
3. Choose **Product → Archive**.
4. In Organizer, select **Distribute App → Developer ID**.
5. Export a Developer ID signed app with Hardened Runtime and a secure timestamp.

Before the first public binary, replace the development bundle identifier with a stable reverse-DNS identifier controlled by the release owner. Do not commit certificates, private keys, provisioning profiles, or notarization credentials.

Debug builds use `com.nasa.ScreenCapture.debug` and appear as **ScreenCapture Dev**. Public Release builds use `com.nasa.ScreenCapture`. Keep these identities separate: macOS screen-recording consent is tied to the bundle identifier and code-signing requirement, not the visible version number. Never install an Apple Development-signed build using the public bundle identifier, because it can invalidate the consent record for the Developer ID-signed app.

## 3. Notarize and package

Store notarization credentials in the login keychain using `notarytool store-credentials`, then run:

```sh
./scripts/release/notarize.sh \
  /path/to/export/ScreenCapture.app \
  KEYCHAIN_PROFILE \
  /path/to/output
```

The script verifies the Developer ID signature, rejects debug entitlements, confirms both CPU architectures, submits the app to Apple, staples and validates the ticket, runs Gatekeeper assessment, creates the final ZIP, and writes its SHA-256 checksum.

## 4. Test the distributed artifact

Test the exact downloaded ZIP—not the Xcode build folder—on a clean Mac or clean user account:

1. Download it through a browser so quarantine metadata is present.
2. Verify the published SHA-256 checksum.
3. Move the app into `/Applications`.
4. Confirm the first-launch Gatekeeper identity message.
5. Exercise permission denial, permission grant, capture, annotation, long capture, export, relaunch, and uninstall.

## 5. Publish a GitHub Release

Create an annotated `vMAJOR.MINOR.PATCH` tag from the verified commit. Attach only the final notarized ZIP and checksum. Release notes must state supported macOS versions, tested hardware, permission requirements, known limitations, and the previous rollback version.

Do not upload Xcode archives, dSYMs, development-signed builds, logs, or notarization credentials as public release assets.
