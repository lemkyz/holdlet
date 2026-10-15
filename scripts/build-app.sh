#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-release}"
swift build "$@" -c "$configuration"
bin_dir="$(swift build "$@" -c "$configuration" --show-bin-path)"
app_dir="$PWD/dist/Holdlet.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/Holdlet" "$app_dir/Contents/MacOS/Holdlet"
cp scripts/Info.plist "$app_dir/Contents/Info.plist"
mkdir -p build
if [[ ! -f build/AppIcon.icns || scripts/make-icon.swift -nt build/AppIcon.icns ]]; then
    swift scripts/make-icon.swift "$PWD/build/AppIcon.iconset"
    iconutil -c icns "$PWD/build/AppIcon.iconset" -o "$PWD/build/AppIcon.icns"
fi
cp build/AppIcon.icns "$app_dir/Contents/Resources/AppIcon.icns"
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$app_dir"
else
    codesign --force --sign - "$app_dir"
fi
printf 'Built %s\n' "$app_dir"
