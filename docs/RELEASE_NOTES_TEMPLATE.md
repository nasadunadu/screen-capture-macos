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
- SHA-256: `CHECKSUM`
- Automated tests: passed
- Manual test matrix: link or summary

## Known limitations

- List release-specific limitations and workarounds.

## Installation

1. Download the notarized ZIP and checksum from this GitHub Release.
2. Verify the checksum.
3. Extract and move `ScreenCapture.app` to `/Applications`.
4. Open the app and grant Screen Recording permission when the first capture starts.

## Rollback

Download the previous notarized release, quit Screen Capture, and replace the app in `/Applications`. Preferences and saved screenshots remain unchanged.
