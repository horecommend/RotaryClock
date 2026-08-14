#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"

for scheme in RotaryClockApp RotaryClockWidget; do
    settings=$(xcodebuild \
        -project "$project_dir/RotaryClock.xcodeproj" \
        -scheme "$scheme" \
        -configuration Debug \
        -sdk iphonesimulator \
        -showBuildSettings 2>/dev/null)

    if ! print -r -- "$settings" | rg -q '^\s*SWIFT_OPTIMIZATION_LEVEL = -Onone$'; then
        print -u2 "FAIL: $scheme Debug is not built with -Onone."
        exit 1
    fi

    if ! print -r -- "$settings" | rg -q '^\s*ENABLE_TESTABILITY = YES$'; then
        print -u2 "FAIL: $scheme Debug does not enable testability for previews."
        exit 1
    fi
done

print "PASS: App and Widget Debug builds are configured for SwiftUI previews."
