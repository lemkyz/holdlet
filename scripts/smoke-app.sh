#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Run on a clean test account/CI runner: this exercises normal app initialization,
# including Bundle/notification/defaults setup that pure model tests do not cover.
result="$(dist/Holdlet.app/Contents/MacOS/Holdlet --smoke-test)"
if [[ "$result" != *"Holdlet normal startup OK"* ]]; then
    printf 'Normal application startup did not complete.\n' >&2
    exit 1
fi
printf '%s\n' "$result"
