#!/bin/zsh
set -euo pipefail

# 真实桌面回归检查：要求当前启动的 iPhone 17 模拟器桌面已放置“转盘时钟”。
# 脚本间隔数秒截取 Widget 区域；像素完全不变就说明系统合成动画没有运行。
booted_id="$(xcrun simctl list devices booted -j \
    | plutil -extract devices xml1 -o - - \
    | plutil -p - \
    | rg -o '[0-9A-F]{8}-[0-9A-F-]{27}' \
    | head -n 1)"

if [[ -z "$booted_id" ]]; then
    print -u2 "FAIL: no booted simulator."
    exit 1
fi

probe_dir="$(mktemp -d -t rotary-widget-rotation)"
trap 'rm -rf "$probe_dir"' EXIT

xcrun simctl io "$booted_id" screenshot "$probe_dir/t0.png" >/dev/null
sleep 4
xcrun simctl io "$booted_id" screenshot "$probe_dir/t4.png" >/dev/null

# iPhone 17 模拟器为 1206 × 2622；这里裁切桌面顶部的中号 Widget。
sips --cropToHeightWidth 700 1080 --cropOffset 220 63 \
    "$probe_dir/t0.png" --out "$probe_dir/widget-t0.png" >/dev/null
sips --cropToHeightWidth 700 1080 --cropOffset 220 63 \
    "$probe_dir/t4.png" --out "$probe_dir/widget-t4.png" >/dev/null

if cmp -s "$probe_dir/widget-t0.png" "$probe_dir/widget-t4.png"; then
    print -u2 "FAIL: Widget pixels are identical after 4 seconds; dial animation is stopped."
    exit 1
fi

print "PASS: Widget pixels changed during the 4-second system-compositor probe."
