# Security Policy

Screen Capture processes potentially sensitive pixels. Security and privacy reports are handled with extra care.

## Supported versions

| Version | Supported |
| --- | --- |
| Latest tagged release | Yes |
| Older releases | Best effort |
| Unreleased development branches | No guarantee |

## Report a vulnerability privately

Use the repository's **Security → Report a vulnerability** flow to open a private GitHub security advisory. Do not include exploit details, captured private content, credentials, or personal information in a public issue.

Please include:

- affected version and macOS version;
- reproducible steps or a minimal proof of concept;
- expected security or privacy boundary;
- observed impact;
- suggested mitigation, if known.

Maintainers will acknowledge a complete report as soon as practical, validate it privately, and coordinate disclosure after a fix is available. This project does not promise a bounty or a fixed response SLA.

## Security boundaries

- Screenshot pixels are intended to remain on the local Mac.
- The app does not include analytics, accounts, telemetry, cloud upload, or third-party runtime dependencies.
- Screen Recording permission is required by macOS for still-image capture.
- Release binaries are official only when linked from a GitHub Release and accompanied by a checksum and successful Apple notarization.
