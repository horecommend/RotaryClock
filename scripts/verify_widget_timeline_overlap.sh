#!/bin/zsh
set -euo pipefail

# WidgetKit 的 .after 日期只是“最早允许系统请求新时间线”的时刻，
# 不是准点回调。旧时间线必须在该时刻之后仍有足够的未来条目，
# 否则系统稍晚刷新就会让小时和日期停在旧值。
provider_file="RotaryClockWidget/RotaryClockWidget.swift"
app_file="RotaryClockApp/RotaryClockApp.swift"

future_hours="$(sed -nE 's/.*let timelineHorizonHours = ([0-9]+).*/\1/p' "$provider_file")"
reload_hours="$(sed -nE 's/.*let reloadAfterHours = ([0-9]+).*/\1/p' "$provider_file")"

if [[ -z "$future_hours" || -z "$reload_hours" ]]; then
    print -u2 "FAIL: provider has no explicit timeline horizon/reload overlap policy."
    exit 1
fi

overlap_hours=$((future_hours - reload_hours))
if (( overlap_hours < 1 )); then
    print -u2 "FAIL: only ${overlap_hours} hours remain after reload request; need at least 1."
    exit 1
fi

if ! rg -q '1\.\.\.timelineHorizonHours' "$provider_file"; then
    print -u2 "FAIL: timeline entries do not use timelineHorizonHours."
    exit 1
fi

if ! rg -q 'hourStart\.addingTimeInterval\(Double\(reloadAfterHours \* 60 \* 60\)\)' "$provider_file"; then
    print -u2 "FAIL: reload date does not use reloadAfterHours."
    exit 1
fi

if ! rg -q 'WidgetCenter\.shared\.reloadTimelines\(ofKind: "RotaryClockWidget"\)' "$app_file"; then
    print -u2 "FAIL: opening the app does not discard a stale widget timeline."
    exit 1
fi

print "PASS: timeline keeps ${overlap_hours} hours of entries after requesting a reload."
