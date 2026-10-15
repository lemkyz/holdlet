# Releasing

## Local developer build

```bash
./scripts/test.sh
./scripts/build-app.sh
./scripts/smoke-app.sh
codesign --verify --deep --strict --verbose=2 dist/Holdlet.app
```

The default ad-hoc signature supports local development, not trusted public distribution. `scripts/build-app.sh` builds the current host architecture. Do not label a single-architecture artifact universal.

Run the startup smoke test on a clean test account or CI runner. It initializes normal app state (not demo state), so it should not be used as an isolation boundary for an existing connected profile.

## Developer ID distribution

Use an Apple Developer account and Developer ID Application identity you control. Do not commit certificates, passwords or API keys. Keep signing materials in an appropriate secrets store.

```bash
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./scripts/build-app.sh
ditto -c -k --sequesterRsrc --keepParent dist/Holdlet.app dist/Holdlet-macOS.zip
xcrun notarytool submit dist/Holdlet-macOS.zip --keychain-profile YOUR_PROFILE --wait
xcrun stapler staple dist/Holdlet.app
spctl --assess --type execute --verbose=2 dist/Holdlet.app
```

Then recreate the ZIP from the stapled bundle and test on a clean Mac. Release notes must state architecture, minimum macOS, provider setup, known limitations, and validation evidence. Never publish test tokens, real mail screenshots, or a misleading “enterprise-ready” claim.

## CI

The CI artifact is an unsigned/ad-hoc **developer build**, not a notarized installer. Test and build run on a macOS runner. Public releases with trusted signatures require separate account-provided credentials and an explicitly configured release workflow.

## Public-beta gate

Run `./scripts/preflight.sh --preview` for the current developer package. It verifies bundle structure and code signature without claiming trusted installation or provider acceptance.

Run `./scripts/preflight.sh --public-beta` before calling a download a public beta. It fails for a missing Developer ID Application signature, missing stapled notarization ticket or missing publisher Google client configuration. It never prints client values. This is an automated subset of release acceptance, not proof of verified provider consent or Slack/Jira availability. Finish the live-account, clean-machine and tenant-policy checks in VALIDATION.md and STATUS.md.

Internal client/token fields belong under Diagnostics → Developer connections. Ordinary users must not be sent to developer consoles to finish onboarding.
