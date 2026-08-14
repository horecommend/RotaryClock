#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
face_file="$project_dir/Shared/RotaryClockFace.swift"
widget_file="$project_dir/RotaryClockWidget/RotaryClockWidget.swift"

for center_name in dialCenter focusCenter; do
    if ! rg -q "let $center_name" "$face_file"; then
        print -u2 "FAIL: missing $center_name geometry."
        exit 1
    fi
done

if [[ "$(rg -c '\.position\(dialCenter\)' "$face_file")" -ne 2 ]]; then
    print -u2 "FAIL: minute and second dials do not share exactly one center."
    exit 1
fi

if ! rg -q 'y: dialCenter\.y' "$face_file"; then
    print -u2 "FAIL: framed values are not horizontally aligned with the dial center."
    exit 1
fi

if ! rg -q 'x: size\.width \* \(compact \? [0-9.]+ : [0-9.]+\)' "$face_file"; then
    print -u2 "FAIL: minute-second capsule is missing its size-specific horizontal position."
    exit 1
fi

if ! rg -q 'y: size\.height / 2' "$face_file"; then
    print -u2 "FAIL: dial center is not vertically centered for every widget size."
    exit 1
fi

if ! rg -q 'value: second' "$face_file"; then
    print -u2 "FAIL: outer dial is not bound to the current second."
    exit 1
fi

if ! rg -q 'value: minute' "$face_file"; then
    print -u2 "FAIL: inner dial is not bound to the current minute."
    exit 1
fi

if rg -q 'labelWindow: -15\.\.\.10' "$face_file"; then
    print -u2 "FAIL: minute dial labels are still limited to a partial window."
    exit 1
fi

if ! rg -q 'rotationStep: continuousSecond' "$face_file" || ! rg -q 'rotationStep: continuousMinute' "$face_file"; then
    print -u2 "FAIL: dial rotations are not using continuous steps across 59 to 00."
    exit 1
fi

if ! rg -q 'clockHandRotationEffect' "$face_file" || ! rg -q 'period: rotationPeriod\.clockHandPeriod' "$face_file"; then
    print -u2 "FAIL: experimental system-driven clock rotation is missing."
    exit 1
fi

if ! rg -q 'timerInterval: startOfHour\.\.\.startOfHour\.addingTimeInterval\(3600\)' "$face_file"; then
    print -u2 "FAIL: widget minute-second digit windows are not system-driven."
    exit 1
fi

if ! rg -q 'let hourText = String\(format: "%02d", hour\)' "$face_file"; then
    print -u2 "FAIL: prominent current-hour text is missing."
    exit 1
fi

if ! rg -q 'HStack\(spacing: -unit \* \(compact \? 0\.018 : 0\.014\)\)' "$face_file"; then
    print -u2 "FAIL: hour digits are missing their compact pair spacing."
    exit 1
fi

if ! rg -q 'weight: \.black, design: \.rounded' "$face_file"; then
    print -u2 "FAIL: hour digits are missing the rounded black reference style."
    exit 1
fi

if ! rg -q 'Text\(String\(hourText\.prefix\(1\)\)\)' "$face_file" || \
   ! rg -q 'Text\(String\(hourText\.suffix\(1\)\)\)' "$face_file"; then
    print -u2 "FAIL: hour digits are not independently laid out against glyph clipping."
    exit 1
fi

if ! rg -q 'dateInterval\(of: \.minute, for: now\)' "$widget_file" || \
   ! rg -q 'minuteStart\.addingTimeInterval\(Double\(offset \* 60\)\)' "$widget_file"; then
    print -u2 "FAIL: Widget timeline entries are not aligned to each 00-second boundary."
    exit 1
fi

if [[ "$(rg -c 'Text\(String\(format: "%02d", (minute|second)\)\)' "$face_file")" -lt 2 ]]; then
    print -u2 "FAIL: framed minute and second values are missing."
    exit 1
fi

if ! rg -q 'containerBackgroundRemovable\(true\)' "$widget_file"; then
    print -u2 "FAIL: widget background cannot be removed for iOS 26 Clear appearance."
    exit 1
fi

if ! rg -q '\.glassEffect\(' "$face_file" || \
   ! rg -q '\.fill\(\.black\.opacity\(0\.46\)\)' "$face_file" || \
   ! rg -q '\.tint\(\.black\.opacity\(0\.42\)\)' "$face_file"; then
    print -u2 "FAIL: minute-second capsule is missing its iOS 26 Liquid Glass background."
    exit 1
fi

if rg -q 'Color\.clear' "$widget_file" && ! rg -q 'isTransparent\(true\)' "$widget_file"; then
    print -u2 "FAIL: clear container is missing the private host-transparency flag."
    exit 1
fi

print "PASS: concentric dials use experimental system-driven rotation and live timer text."
