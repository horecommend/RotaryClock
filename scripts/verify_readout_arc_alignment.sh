#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
face_file="${FACE_FILE:-$project_dir/Shared/RotaryClockFace.swift}"

# 分钟盘和秒盘的半径分别为 0.36 / 0.53 unit，因此它们在水平中心线
# 上的交点相距 0.17 unit。读数中心也必须使用同一间距。
if ! rg -q 'let readoutCenterSeparation = unit \* 0\.17' "$face_file"; then
    print -u2 "FAIL: minute/second readout centers are not aligned to the two dial arcs."
    exit 1
fi

if ! rg -q 'x: capsuleWidth / 2 - readoutCenterSeparation / 2' "$face_file" || \
   ! rg -q 'x: capsuleWidth / 2 \+ readoutCenterSeparation / 2' "$face_file"; then
    print -u2 "FAIL: minute and second values do not use independent arc-centered positions."
    exit 1
fi

# Widget 必须保留完整系统 Timer，不能退回静态秒数或裁切动态 Text。
if [[ "$(rg -c 'timerInterval: startOfHour\.\.\.startOfHour\.addingTimeInterval\(3600\)' "$face_file")" -ne 1 ]]; then
    print -u2 "FAIL: widget fixed MM:SS live timer source is missing or duplicated."
    exit 1
fi

if ! rg -q 'showsHours: false' "$face_file"; then
    print -u2 "FAIL: widget timer still reserves invisible hour-field width."
    exit 1
fi

if rg -Uq 'if minute < 10\s*\{\s*Text\("0"\)' "$face_file"; then
    print -u2 "FAIL: widget timer still has a stale-entry leading zero."
    exit 1
fi

if ! rg -q '\.minimumScaleFactor\(0\.72\)' "$face_file"; then
    print -u2 "FAIL: widget timer cannot fit safely inside the narrow capsule."
    exit 1
fi

if ! rg -q '\.offset\(x: unit \*' "$face_file"; then
    print -u2 "FAIL: widget timer wrapper is missing its visible-glyph centering correction."
    exit 1
fi

if ! rg -Uq 'width: capsuleWidth,[[:space:]]*height: capsuleHeight,[[:space:]]*alignment: \.center' "$face_file"; then
    print -u2 "FAIL: widget timer is not centered inside the full capsule frame."
    exit 1
fi

print "PASS: minute and second readouts are centered on their corresponding dial arcs."
