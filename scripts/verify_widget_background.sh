#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
widget_file="$project_dir/RotaryClockWidget/RotaryClockWidget.swift"
project_file="$project_dir/RotaryClock.xcodeproj/project.pbxproj"
private_sdk="$project_dir/PrivateSDK/WidgetKit.swiftmodule"

if ! rg -q 'Color\.clear' "$widget_file"; then
    print -u2 "FAIL: Experimental Widget container is not clear."
    exit 1
fi

if ! rg -q 'isTransparent\(true\)' "$widget_file"; then
    print -u2 "FAIL: Private WidgetConfiguration transparency flag is missing."
    exit 1
fi

if ! rg -q 'containerBackgroundRemovable\(true\)' "$widget_file"; then
    print -u2 "FAIL: iOS 26 cannot replace the fallback background in Clear appearance."
    exit 1
fi

if [[ ! -f "$private_sdk/arm64-apple-ios-simulator.swiftinterface" || \
      ! -f "$private_sdk/x86_64-apple-ios-simulator.swiftinterface" || \
      ! -f "$private_sdk/arm64e-apple-ios.swiftinterface" ]]; then
    print -u2 "FAIL: Private WidgetKit interfaces are incomplete."
    exit 1
fi

if ! rg -q 'SWIFT_INCLUDE_PATHS = "\$\(PROJECT_DIR\)/PrivateSDK"' "$project_file"; then
    print -u2 "FAIL: Widget target does not load the private WidgetKit interface."
    exit 1
fi

print "PASS: Widget uses the private Swift ABI transparency experiment with a clear container."
