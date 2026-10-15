#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app_dir="${HOLDLET_APP_PATH:-$PWD/dist/Holdlet.app}"
channel="${1:---preview}"
if [[ "$channel" != --preview && "$channel" != --public-beta ]]; then
    printf 'Usage: %s [--preview|--public-beta]\n' "$0" >&2
    exit 2
fi
plutil -lint "$app_dir/Contents/Info.plist"
codesign --verify --deep --strict "$app_dir"
if [[ "$channel" == --preview ]]; then
    printf 'Preview bundle verified. This does not certify public sign-in or trusted installation.\n'
    exit 0
fi
failures=0
identity="$(codesign -d --verbose=4 "$app_dir" 2>&1)"
if [[ "$identity" != *"Authority=Developer ID Application:"* ]]; then
    printf 'BLOCKED: Developer ID Application signature is required.\n' >&2
    failures=$((failures + 1))
fi
if ! xcrun stapler validate "$app_dir" >/dev/null 2>&1; then
    printf 'BLOCKED: A valid stapled notarization ticket is required.\n' >&2
    failures=$((failures + 1))
fi
if ! client_id="$(plutil -extract HoldletGoogleClientID raw -o - "$app_dir/Contents/Info.plist" 2>/dev/null)" || [[ ! "$client_id" =~ ^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$ ]]; then
    printf 'BLOCKED: Publisher Google client configuration is missing.\n' >&2
    failures=$((failures + 1))
fi
if ((failures > 0)); then exit 1; fi
printf 'Automated public-beta checks passed. Complete the live-account and clean-machine acceptance matrix before publishing.\n'
