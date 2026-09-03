# Privacy

Screen Capture is designed around a simple boundary: screenshot pixels stay on the Mac unless the user explicitly copies or saves them.

## Data handling

- Captured pixels are processed in local memory.
- The app does not send screenshots, annotations, preferences, or usage events over the network.
- The app has no account system, analytics SDK, advertising SDK, crash-reporting SDK, or cloud service.
- The app stores only user preferences in `UserDefaults`.
- Clipboard and file writes occur only after an explicit user action.

## Permissions

macOS places still-image capture behind the Screen Recording permission. Screen Capture requests that permission only when capture begins. The app does not record video or audio.

The current manual scrolling-capture design does not require Accessibility permission.

## Source verification

The application has no third-party runtime package dependencies. Release users should download only artifacts attached to this project's GitHub Releases and verify the published SHA-256 checksum. Official direct-distribution artifacts are Developer ID signed and notarized by Apple.

## Privacy reports

Report a suspected privacy boundary violation privately by following [SECURITY.md](../SECURITY.md).
