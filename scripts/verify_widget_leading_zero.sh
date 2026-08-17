#!/bin/zsh
set -euo pipefail

# iOS 26 当前时间格式器直接输出两位分钟与两位秒钟；不通过静态前导零或
# 时长 Timer 拼接，以避免“011:59”和“65:00”。
face_file="Shared/RotaryClockFace.swift"

if ! rg -Uq '\.dateTime\.minute\(\.twoDigits\)\.second\(\.twoDigits\)' "$face_file"; then
    print -u2 "FAIL: Widget readout does not request two-digit minute and second fields."
    exit 1
fi

if rg -q 'if minute < 10' "$face_file"; then
    print -u2 "FAIL: Widget still uses a static leading-zero prefix that can become stale."
    exit 1
fi

print "PASS: Widget readout has live two-digit MM:SS clock fields."
