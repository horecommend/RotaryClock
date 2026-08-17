#!/bin/zsh
set -euo pipefail

# 真机 Widget 的动态当前时间不能与 fixedSize / clipped 组合，否则可能丢失
# 整个 Text 图层。这里锁定 iOS 26 的实时钟表文本布局。
face_file="Shared/RotaryClockFace.swift"

if ! rg -Uq 'Text\(\s*\.currentDate,\s*format: \.dateTime\.minute\(\.twoDigits\)\.second\(\.twoDigits\)\s*\)' "$face_file"; then
    print -u2 "FAIL: Widget is not using the visibility-safe live current-clock MM:SS configuration."
    exit 1
fi

if rg -q 'timerInterval:' "$face_file"; then
    print -u2 "FAIL: Widget still uses a bounded timerInterval and can advance past 59:59."
    exit 1
fi

if rg -Uq '\.currentDate[\s\S]{0,900}\.fixedSize\(horizontal: true, vertical: false\)' "$face_file" || \
   rg -Uq '\.currentDate[\s\S]{0,900}\.clipped\(\)' "$face_file"; then
    print -u2 "FAIL: Widget live clock text still has a clipping modifier that can remove the text layer."
    exit 1
fi

print "PASS: Widget live clock text uses the real-device visibility-safe layout."
