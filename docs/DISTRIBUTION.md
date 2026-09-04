# Direct distribution

This personal open-source project distributes the macOS app outside the Mac App Store. Source availability and binary release readiness are separate gates: a source commit may be public while a downloadable app remains a prerelease.

## Release inputs

- a clean commit on the release branch;
- an explicit semantic version and matching changelog entry;
- the complete automated and manual release checklist;
- a valid local **Developer ID Application** identity and private key for signing the custom DMG;
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

Xcode cloud signing can export the app with a **Cloud Managed Developer ID Application** certificate, but its private key is not installed in the local keychain. This release workflow also signs the custom DMG, so create or import a traditional **Developer ID Application** identity for the same team in **Xcode → Settings → Accounts → Manage Certificates** before running the notarization script.

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

The script verifies the Developer ID signature, rejects debug entitlements, confirms both CPU architectures, submits and staples the app, creates the final DMG and fallback ZIP, signs the DMG with the app's Developer ID identity, notarizes and staples the DMG, runs Gatekeeper assessment, and writes a SHA-256 checksum beside each download. The DMG presents `ScreenCapture.app` and an `Applications` shortcut at its root so installation is a direct drag-and-drop.

## 4. Test the distributed artifact

Test the exact downloaded DMG—not the Xcode build folder—on a clean Mac or clean user account:

1. Download it through a browser so quarantine metadata is present.
2. Verify the published DMG SHA-256 checksum.
3. Open the DMG and drag the app into `Applications`.
4. Confirm the first-launch Gatekeeper identity message.
5. Exercise permission denial, permission grant, capture, annotation, long capture, export, relaunch, and uninstall.

## 5. Publish a GitHub Release

Create an annotated `vMAJOR.MINOR.PATCH` tag from the verified commit. Attach the final notarized DMG, fallback ZIP, and both checksum files. Release notes must state supported macOS versions, tested hardware, permission requirements, known limitations, and the previous rollback version.

Do not upload Xcode archives, dSYMs, development-signed builds, logs, or notarization credentials as public release assets.
