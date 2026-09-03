## What changed

Describe the user-visible or engineering change.

## Why

Explain the problem and the intended outcome.

## Validation

- [ ] Relevant regression tests were added or updated.
- [ ] `./scripts/ci.sh` passes.
- [ ] The affected capture flow was tested manually when system UI or permissions are involved.
- [ ] UI changes include sanitized before/after screenshots.

## Privacy and security

- [ ] Captured pixels remain local unless the user explicitly copies or saves them.
- [ ] No credentials, provisioning profiles, private screenshots, logs, or generated build products are included.
- [ ] New permissions, network behavior, or data persistence are documented.

## Risk and rollback

State the likely failure mode and how this change can be reverted safely.
