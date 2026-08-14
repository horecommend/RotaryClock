#!/bin/zsh
set -euo pipefail

# WidgetKit 的 .after 日期只是“最早允许系统请求新时间线”的时刻，
# 不是准点回调。旧时间线必须在该时刻之后仍有足够的未来条目，
# 否则系统稍晚刷新就会让时钟停在 60:00。
provider_file="RotaryClockWidget/RotaryClockWidget.swift"
app_file="RotaryClockApp/RotaryClockApp.swift"

future_minutes="$(sed -nE 's/.*let timelineHorizonMinutes = ([0-9]+).*/\1/p' "$provider_file")"
reload_minutes="$(sed -nE 's/.*let reloadAfterMinutes = ([0-9]+).*/\1/p' "$provider_file")"

if [[ -z "$future_minutes" || -z "$reload_minutes" ]]; then
    print -u2 "FAIL: provider has no explicit timeline horizon/reload overlap policy."
    exit 1
fi

overlap_minutes=$((future_minutes - reload_minutes))
if (( overlap_minutes < 60 )); then
    print -u2 "FAIL: only ${overlap_minutes} minutes remain after reload request; need at least 60."
    exit 1
fi

if ! rg -q 'let entries = \(0\.\.\.timelineHorizonMinutes\)\.map' "$provider_file"; then
    print -u2 "FAIL: timeline entries do not use timelineHorizonMinutes."
    exit 1
fi

if ! rg -q 'minuteStart\.addingTimeInterval\(Double\(reloadAfterMinutes \* 60\)\)' "$provider_file"; then
    print -u2 "FAIL: reload date does not use reloadAfterMinutes."
    exit 1
fi

if ! rg -q 'WidgetCenter\.shared\.reloadTimelines\(ofKind: "RotaryClockWidget"\)' "$app_file"; then
    print -u2 "FAIL: opening the app does not discard a stale widget timeline."
    exit 1
fi

print "PASS: timeline keeps ${overlap_minutes} minutes of entries after requesting a reload."
