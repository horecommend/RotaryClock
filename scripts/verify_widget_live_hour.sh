#!/bin/zsh
set -euo pipefail

# 透明 Widget 的额外 `.currentDate` 日期格式在 iOS 26 会错误地复用同一段文字，
# 甚至让小时消失。小时和三行日期必须来自分钟级 TimelineEntry；只有分秒
# 使用当前时间数据源。
face_file="Shared/RotaryClockFace.swift"

if ! rg -q 'let hourText = String\(format: "%02d", hour\)' "$face_file"; then
    print -u2 "FAIL: hour is not derived from the timeline entry."
    exit 1
fi

for field in 'Text\(solarDate\)' 'Text\(weekday\)' 'Text\(lunarDate\)'; do
    if ! rg -q "$field" "$face_file"; then
        print -u2 "FAIL: calendar field $field is missing from the entry-backed date block."
        exit 1
    fi
done

if rg -Uq 'Text\(\s*\.currentDate,\s*format: \.dateTime\.hour' "$face_file"; then
    print -u2 "FAIL: transparent Widget still uses a live currentDate hour."
    exit 1
fi

if ! rg -q 'let hourCenterX = dialCenter\.x \+' "$face_file" || \
   ! rg -q '\.position\(x: hourCenterX, y: focusCenter\.y\)' "$face_file"; then
    print -u2 "FAIL: Widget hour no longer uses its original alignment."
    exit 1
fi

print "PASS: Widget hour and calendar fields use stable timeline-entry text."
