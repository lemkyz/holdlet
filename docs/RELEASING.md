# Releasing

## Local developer build

```bash
./scripts/test.sh
./scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 dist/Holdlet.app
```

The default ad-hoc signature supports local development, not trusted public distribution. `scripts/build-app.sh` builds the current host architecture. Do not label a single-architecture artifact universal.

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
