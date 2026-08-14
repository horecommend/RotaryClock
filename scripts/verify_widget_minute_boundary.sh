#!/bin/zsh
set -euo pipefail

# 专门验证秒盘越过 xx:xx:00 后仍继续旋转。
booted_id="$(xcrun simctl list devices booted -j \
    | plutil -extract devices xml1 -o - - \
    | plutil -p - \
    | rg -o '[0-9A-F]{8}-[0-9A-F-]{27}' \
    | head -n 1)"

if [[ -z "$booted_id" ]]; then
    print -u2 "FAIL: no booted simulator."
    exit 1
fi

probe_dir="$(mktemp -d -t rotary-widget-boundary)"
trap 'rm -rf "$probe_dir"' EXIT

# 最多等待 55 秒，使第一张图落在 56 秒附近。
current_second=$((10#$(date +%S)))
if (( current_second >= 50 )); then
    wait_seconds=0
else
    wait_seconds=$((56 - current_second))
fi
sleep "$wait_seconds"

xcrun simctl io "$booted_id" screenshot "$probe_dir/pre.png" >/dev/null
sleep 6
xcrun simctl io "$booted_id" screenshot "$probe_dir/post-02.png" >/dev/null
sleep 4
xcrun simctl io "$booted_id" screenshot "$probe_dir/post-06.png" >/dev/null

for name in pre post-02 post-06; do
    sips --cropToHeightWidth 700 1080 --cropOffset 220 63 \
        "$probe_dir/$name.png" --out "$probe_dir/widget-$name.png" >/dev/null
done

if cmp -s "$probe_dir/widget-pre.png" "$probe_dir/widget-post-02.png"; then
    print -u2 "FAIL: Widget did not change across the 00-second boundary."
    exit 1
fi

if cmp -s "$probe_dir/widget-post-02.png" "$probe_dir/widget-post-06.png"; then
    print -u2 "FAIL: Widget changed at 00 but stopped during the new minute."
    exit 1
fi

print "PASS: Widget crossed 00 seconds and kept moving in the new minute."
