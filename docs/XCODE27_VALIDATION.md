# Xcode 27 compatibility validation — 2026-09-20

## Supported platforms

Apple Silicon (arm64), macOS 14 or later, including macOS 14–26 and macOS 27.
Intel Macs are unsupported for the upcoming release. Historical v0.4.14
universal downloads remain unchanged.

## Changes

- Explicit arm64-only project and packaging configuration.
- Packaging verifies LSMinimumSystemVersion is 14.0 and rejects other architectures.
- Keep Xcode 26.6 CI and add an Xcode 27 job using GitHub's `xcode-27` runner.
- Resolve the new compiler's implicit-strong/explicit-weak nested capture warning
  in the one-shot color picker without replacing annotation presentation.

## Verified locally

Environment: Xcode 27.0 (27A266a), macOS 27.0 (26A428).
`./scripts/ci.sh` passed after the final macOS 14 / arm64 configuration:

- 85 tests passed, including settings numeric changes, selection interaction,
  retained toolbar hierarchy, permission request gating, export and stitching.
- Release static analysis and build succeeded.
- Binary architecture: exactly arm64. LSMinimumSystemVersion: 14.0.
- DMG / ZIP packaging and SHA-256 verification passed.
- Color-picker capture warning no longer appears. The build still reports the
  informational App Intents metadata skip because this app does not use App Intents.

## Not yet verified / release gates

- GitHub jobs have not run for these local changes.
- Real macOS 14–26 machines were not tested; deployment settings alone do not
  prove runtime compatibility.
- Manual macOS 27 acceptance remains required: round-corner and width sliders,
  color panel, first stroke, toolbar persistence, drag/resize, Escape, Settings,
  permission revoke/grant/relaunch, multi-display capture and fast long capture.
- No installed application replacement, public release, or notarization was
  performed for this compatibility change. Do not distribute unsigned CI builds.

## References

- [Apple macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes)
- [Apple Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)
- [GitHub runner images](https://github.com/actions/runner-images)
