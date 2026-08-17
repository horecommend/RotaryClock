#!/bin/zsh
set -euo pipefail

# 透明 Widget 宿主会移除小时 currentDate Text 或追加 locale 的“时”。
# 小时要使用 timeline entry 提供的两个纯数字 Text；Provider 每分钟接力。
face_file="Shared/RotaryClockFace.swift"

if ! rg -q 'Text\(String\(hourText\.prefix\(1\)\)\)' "$face_file" || \
   ! rg -q 'Text\(String\(hourText\.suffix\(1\)\)\)' "$face_file"; then
    print -u2 "FAIL: Widget hour is not rendered as two static numeric digits."
    exit 1
fi

if rg -q '\.hour\(\.twoDigits' "$face_file"; then
    print -u2 "FAIL: Widget hour still uses currentDate formatting that can show 时 or disappear."
    exit 1
fi

if ! rg -q 'let hourCenterX = dialCenter\.x \+ 30' "$face_file" || \
   ! rg -q '\.position\(x: hourCenterX, y: focusCenter\.y\)' "$face_file"; then
    print -u2 "FAIL: Widget hour no longer uses its original alignment."
    exit 1
fi

if ! rg -q 'let entries = \(0\.\.\.timelineHorizonMinutes\)\.map' RotaryClockWidget/RotaryClockWidget.swift; then
    print -u2 "FAIL: Widget hour has no minute-by-minute timeline handoff."
    exit 1
fi

print "PASS: Widget hour uses visible numeric digits with minute-by-minute timeline handoff."
