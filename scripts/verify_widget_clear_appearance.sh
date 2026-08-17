#!/bin/zsh
set -euo pipefail

# iOS 26 的“透明”桌面外观可能在切换或重新加载 Widget 时给内容
# 注入 placeholder redaction，并按 accented 模式重新解释颜色。时钟没有
# 隐私数据，应该主动取消占位，同时保留原始白色文字与刻度。
project_dir="${0:A:h:h}"
widget_file="$project_dir/RotaryClockWidget/RotaryClockWidget.swift"
face_file="$project_dir/Shared/RotaryClockFace.swift"
placeholder_body="$(sed -n '/func placeholder/,/^    }/p' "$widget_file")"

if ! print -r -- "$placeholder_body" | rg -q 'RotaryClockEntry\(date: \.now\)'; then
    print -u2 "FAIL: unredacted Clear appearance would expose a stale placeholder time."
    exit 1
fi

if print -r -- "$placeholder_body" | rg -q 'timeIntervalSince1970'; then
    print -u2 "FAIL: Widget placeholder still contains a hard-coded date."
    exit 1
fi

if ! rg -q '\.unredacted\(\)' "$widget_file"; then
    print -u2 "FAIL: Clear appearance can replace every clock Text with placeholder blocks."
    exit 1
fi

if ! rg -q '\.widgetAccentable\(false\)' "$widget_file"; then
    print -u2 "FAIL: Clear/Tinted appearance can reinterpret clock content as an accent mask."
    exit 1
fi

if ! rg -q 'dateInterval\(of: \.minute, for: now\)' "$widget_file"; then
    print -u2 "FAIL: Widget no longer schedules per-minute entries for the leading-zero prefix."
    exit 1
fi

print "PASS: Clear appearance keeps clock text unredacted and full-color."
