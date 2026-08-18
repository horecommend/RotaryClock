#!/bin/zsh
set -euo pipefail

# 小号布局必须单独映射，并在 Widget 配置中公开；所有尺寸都应显示三行日期。
face_file="Shared/RotaryClockFace.swift"
widget_file="RotaryClockWidget/RotaryClockWidget.swift"

if ! rg -q 'case small' "$face_file" || ! rg -q 'let compact = layout == \.small \|\| layout == \.medium' "$face_file"; then
    print -u2 "FAIL: RotaryClockFace has no compact small layout."
    exit 1
fi

if ! rg -q 'case \.systemSmall:' "$widget_file" || ! rg -q '\.supportedFamilies\(\[\.systemSmall, \.systemMedium, \.systemLarge\]\)' "$widget_file"; then
    print -u2 "FAIL: Widget configuration does not expose systemSmall."
    exit 1
fi

if ! rg -q 'dateBlock\(unit: unit, layout: layout\)' "$face_file" || \
   ! rg -q 'Text\(solarDate\)' "$face_file" || \
   ! rg -q 'Text\(weekday\)' "$face_file" || \
   ! rg -q 'Text\(lunarDate\)' "$face_file"; then
    print -u2 "FAIL: Small layout does not include the three-line date block."
    exit 1
fi

print "PASS: Widget exposes a systemSmall layout with the three-line date block."
