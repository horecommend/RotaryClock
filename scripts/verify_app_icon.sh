#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
icon="$project_dir/RotaryClockApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
contents="$project_dir/RotaryClockApp/Assets.xcassets/AppIcon.appiconset/Contents.json"
project="$project_dir/RotaryClock.xcodeproj/project.pbxproj"

if [[ ! -f "$icon" || ! -f "$contents" ]]; then
    print -u2 "FAIL: AppIcon asset catalog is incomplete."
    exit 1
fi

width="$(sips -g pixelWidth "$icon" | awk '/pixelWidth/ {print $2}')"
height="$(sips -g pixelHeight "$icon" | awk '/pixelHeight/ {print $2}')"
if [[ "$width" != 1024 || "$height" != 1024 ]]; then
    print -u2 "FAIL: AppIcon master must be 1024x1024."
    exit 1
fi

if ! rg -q 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon' "$project" || \
   ! rg -q 'Assets\.xcassets in Resources' "$project"; then
    print -u2 "FAIL: App target is not configured to compile AppIcon."
    exit 1
fi

print "PASS: AppIcon is a compiled 1024x1024 asset catalog resource."
