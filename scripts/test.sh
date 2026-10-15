#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Command Line Tools 26 ships Testing.framework without SwiftPM's automatic search path.
# Full Xcode generally needs no override. Discover the framework from the selected toolchain.
developer_dir="$(xcode-select -p)"
frameworks="$developer_dir/Library/Developer/Frameworks"
if [[ -d "$frameworks/Testing.framework" ]]; then
    swift test "$@" -Xswiftc -F -Xswiftc "$frameworks" \
        -Xlinker "-F$frameworks" -Xlinker -rpath -Xlinker "$frameworks" \
        -Xlinker -rpath -Xlinker "$developer_dir/Library/Developer/usr/lib"
else
    swift test "$@"
fi
