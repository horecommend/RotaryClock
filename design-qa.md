# Design QA — RotaryClock

- Source visual truth: `/Users/thomas/Downloads/截屏 2026-08-14 11.53.47.png`
- Implementation screenshot: `/Users/thomas/Documents/Codex/2026-08-14/kai-f/work/rotary-clock-final-v5.png`
- Combined comparison: `/Users/thomas/Documents/Codex/2026-08-14/kai-f/work/rotary-clock-final-comparison-v3.png`
- Source pixels: 1320 × 1413
- Implementation pixels: 1206 × 2622 (iPhone 17 simulator, 402 × 874 points, 3× density)
- Normalized comparison: source crop 1320 × 1320 at y=93 and implementation app-face crop 1206 × 1206 at y=708, both resized to 600 × 600
- State: dark appearance, live current time, Simplified Chinese locale

## Full-view comparison evidence

The normalized side-by-side comparison confirms the same primary composition: gray-to-black transparent-context preview, oversized current hour at left, concentric inner-minute and outer-second scales, an outlined capsule with current minute and second values, and two-line calendar data at right. Dynamic clock values necessarily differ from the reference capture.

## Focused region comparison evidence

The central clock face was inspected at original simulator density. The capsule stroke, monospaced numerals, major/minor tick contrast, date clearance, clipping at the outer dial, and Chinese lunar copy remain legible without raster assets. A separate crop was not required because these details are clearly readable in the 1200 × 600 combined comparison.

## Required fidelity surfaces

- Fonts and typography: SF Rounded/system typography with monospaced digits reproduces the reference's neutral rounded numerals and keeps live values stable. Weight hierarchy is preserved.
- Spacing and layout rhythm: hour, capsule, and date retain the reference's left/center/right axis. Oversized dial radii intentionally clip beyond the widget bounds.
- Colors and visual tokens: white foreground with graduated opacity over a clear WidgetKit container; the host app uses a gray-to-black preview background only.
- Image quality and asset fidelity: no raster imagery is present in the reference clock face. Native SwiftUI vectors keep ticks and strokes sharp at every widget scale.
- Copy and content: Gregorian date, Simplified Chinese weekday, and calculated Chinese lunar month/day are live rather than hard-coded.

## Comparison history

1. Initial capture: P2 — dial radii were too close, causing labels to pile up at the capsule. Fix: expanded radii to 0.19/0.33/0.48 of the layout unit and standardized 00/05/10… labels. Post-fix evidence: `/Users/thomas/Documents/Codex/2026-08-14/kai-f/work/rotary-clock-app-3.png`.
2. Second capture: P2 — full circular scales crossed through the date block. Fix: clipped the rotary layer before the date column. Post-fix evidence: `/Users/thomas/Documents/Codex/2026-08-14/kai-f/work/rotary-clock-final.png`.
3. Widget gallery capture: P1 — a clear, removable WidgetKit container fell back to the system white card, hiding white clock content. Fix: replaced the clear container with the reference-matched gray-to-black gradient and set `containerBackgroundRemovable(false)`. Regression command: `scripts/verify_widget_background.sh` passes; the iOS 26 simulator build succeeds. Post-fix host evidence: `/Users/thomas/Documents/Codex/2026-08-14/kai-f/work/rotary-clock-background-fixed.png`.
4. Interaction clarification: the inner minute scale and outer second scale intentionally share one `dialCenter`; only their radii differ. The second scale advances each second, while the minute scale advances when the minute changes.
5. Same-time comparison: P2 — scale values rotated in the opposite direction, putting 50/45/40 above the capsule instead of sweeping downward. Fix: reversed the signed dial rotation and added per-ring anchor angles.
6. Final polish: P2 — labels from adjacent rings collided around the capsule. Fix: spread the offset centers, use radius-aware label sizing, and restrict labels to the visible value windows represented by the source. Post-fix evidence: `/Users/thomas/Documents/Codex/2026-08-14/kai-f/work/rotary-clock-final-comparison-v3.png`.

## Findings

No actionable P0/P1/P2 mismatch remains. The reference uses a different moment in time, so its dial rotations and displayed values differ as expected.

## Follow-up polish

- P3: A future configurable style could expose ring density, font weight, and whether the `农历` prefix is shown.
- P3: WidgetKit may throttle second-level updates on the Home Screen even though the host app preview updates every second.

final result: passed
