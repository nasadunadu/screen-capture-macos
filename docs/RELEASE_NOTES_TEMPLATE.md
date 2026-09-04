# Screen Capture vX.Y.Z

## Highlights

- Describe the user-visible release value.

## Requirements

- macOS 14 or later
- Screen Recording permission for still-image capture

## Verification

- Commit: `RELEASE_COMMIT`
- Apple notarization: accepted and stapled
- Architectures: `arm64`, `x86_64`
- DMG SHA-256: `DMG_CHECKSUM`
- ZIP SHA-256: `ZIP_CHECKSUM`
- Automated tests: passed
- Manual test matrix: link or summary

## Known limitations

- List release-specific limitations and workarounds.

## Installation

1. Download the notarized DMG and its checksum from this GitHub Release. The ZIP is provided as a fallback.
2. Verify the checksum.
3. Open the DMG and drag `ScreenCapture.app` to `Applications`.
4. Open the app and grant Screen Recording permission when the first capture starts.

## Rollback

Download the previous notarized release, quit Screen Capture, and replace the app in `/Applications`. Preferences and saved screenshots remain unchanged.
