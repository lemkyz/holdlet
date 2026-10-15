# Security

This is a developer alpha. Do not use it as the sole delivery channel for critical obligations. There is no compliance certification or guaranteed background delivery.

Do not post tokens, OAuth codes, client-secret JSON, real messages or local snapshot files in public issues. Report vulnerabilities through GitHub's private vulnerability reporting on this repository when enabled. If it is unavailable, open a content-free issue asking the maintainer for a private channel; do not include exploit details or sensitive data publicly.

Credentials are stored in macOS Keychain. The local state file is access-restricted but not application-encrypted. API calls are made directly to connected services; there is no telemetry backend. Disconnect removes local credentials and data; provider-side revocation is a separate action in the provider account settings. See [architecture](docs/ARCHITECTURE.md).

Only the current main branch is supported during the alpha period. Signed/notarized distribution, external security review and a formal release support policy remain future milestones.
