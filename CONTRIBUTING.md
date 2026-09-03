# Contributing

Thank you for helping improve Screen Capture. Small, focused changes with clear validation are the easiest to review.

## Before you start

- Search existing issues before opening a duplicate.
- Open an issue before implementing a large feature or changing the capture workflow.
- Keep screenshot pixels local. Do not add analytics, upload, account, OCR, recording, translation, or network behavior without prior project discussion.
- Do not include personal screenshots, crash reports, signing identities, provisioning profiles, or credentials in a contribution.

## Development setup

1. Use macOS 14 or later and Xcode 26 or later.
2. Clone the repository and open `ScreenCapture.xcodeproj`.
3. Select your own development team if Xcode requests one.
4. Grant Screen Recording permission only to the locally built app you intend to test.

Run the complete local validation:

```sh
./scripts/ci.sh
```

## Pull requests

- Create a focused branch from `main`.
- Add or update regression tests for behavior changes.
- Keep user-visible strings and documentation accurate.
- Describe the change, validation, risk, and rollback in the pull request template.
- Include sanitized screenshots for visible UI changes.
- Confirm that `git diff --check` passes and the working tree contains no generated artifacts.

## Code style

- Prefer native Swift, SwiftUI, AppKit, ScreenCaptureKit, Vision, and Core Graphics APIs.
- Keep capture, annotation, and stitching logic deterministic and independently testable.
- Treat permission denial, cancellation, invalid geometry, and resource limits as recoverable states.
- Preserve strict Swift concurrency checking.
- Avoid force unwraps and unbounded image allocations in capture paths.

## Reporting bugs

Use the bug-report issue form and include the macOS version, Mac model, app version, exact steps, and expected result. Remove private content from screenshots and logs before attaching them.

Security and privacy problems must follow [SECURITY.md](SECURITY.md) instead of a public issue.
