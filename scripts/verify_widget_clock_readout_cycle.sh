#!/bin/zsh
set -euo pipefail

# 分秒读数必须来自 iOS 26 的系统当前时间源：它按真实时钟格式化，
# 因此能够从 59:59 自动进到 00:00。任何 timerInterval 都是“时长”
# 计数器，分钟会累加到 60、65…，不能用作钟表读数。
face_file="Shared/RotaryClockFace.swift"

if ! rg -Uq 'Text\(\s*\.currentDate,\s*format: \.dateTime\.minute\(\.twoDigits\)\.second\(\.twoDigits\)\s*\)' "$face_file"; then
    print -u2 "FAIL: Widget readout is not a live current-clock MM:SS format."
    exit 1
fi

if rg -q 'timerInterval:' "$face_file"; then
    print -u2 "FAIL: bounded timerInterval remains in the clock readout and can accumulate past 59:59."
    exit 1
fi

print "PASS: Widget MM:SS is sourced from the live current clock and wraps each hour."
