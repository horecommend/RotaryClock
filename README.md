# RotaryClock

一个使用 SwiftUI 与 WidgetKit 编写的 iOS 26 转盘时钟，支持中号和大号桌面小组件，并包含实验性透明背景。

## 使用

1. 用 Xcode 26 打开 `RotaryClock.xcodeproj`。
2. 在 Signing & Capabilities 中为 App 与 Widget 选择你的 Team。
3. 运行 `RotaryClockApp` 到 iOS 26 模拟器或真机。
4. 回到桌面，长按并添加“转盘时钟”。

Widget 当前使用私有 Swift ABI 透明实验：内容容器绘制 `Color.clear`，组件配置调用系统隐藏的 `isTransparent(true)`。如果系统接受这个配置标记，普通主屏幕外观也会直接透出壁纸；若当前 iOS 构建忽略该标记，仍可能显示系统卡片。公开的可移除背景标记同时保留，因此 iOS 26 的“透明/Clear”外观仍可回退到 Liquid Glass。

## 界面微调入口

主要修改 `Shared/RotaryClockFace.swift`，里面已经按区域写好中文注释。建议按这个顺序调整：

1. `dialCenter`：同时控制秒盘和分钟盘的位置，确保两个转盘同心；其 y 使用 `size.height / 2`，在任何组件尺寸中都上下居中。`focusCenter.x` 控制分钟秒钟胶囊的左右位置。
2. `readoutCenterSeparation`：分钟与秒钟的中心距，当前为 `0.17 × unit`，正好对应 `0.36 / 0.53 × unit` 两条圆弧在水平中心线上的交点距离。
3. Widget 使用居中的 `HStack` 包住系统 `timerInterval(..., showsHours: false)`；分钟小于 10 时由 Timeline entry 补前导 `0`，并用 `minimumScaleFactor` 适配当前 `0.30 × unit` 的窄胶囊，避免任何分钟数字被裁切。
4. 两个 `DialRing` 的 `radius`：圆盘大小。
5. `anchorAngle`：整圈刻度的旋转起点。
6. `labelWindow`：可限制圆盘上显示多少个数字；当前分钟盘不传该参数，因此完整显示 `00...55` 的 12 个五分钟数值。
7. 小时使用接近效果图的 SF Pro Rounded Black；两个数字分别放在 `HStack` 中，负 `spacing` 控制紧凑程度，且不会裁掉第二个数字。`currentMinuteAndSecond`、日期文字的 `.position(...)` 控制前景文字位置。
8. `RotaryClockApp.swift`：App 页面背景；`RotaryClockWidget.swift`：Widget 背景、边距和预览尺寸。

所有坐标和尺寸都尽量乘以 `unit`，这样修改后仍能同时适配中号与大号 Widget。

时间显示关系固定为：大号数字显示当前小时，内转盘显示分钟，外转盘显示秒；中间胶囊同时显示当前分钟和秒钟。

分秒胶囊使用 iOS 26 公开的 `.glassEffect(.regular.tint(...), in: Capsule())` 原生 Liquid Glass。`.fill(.black.opacity(...))` 控制数字背后的遮挡强度，`tint` 控制玻璃色调；两者调低会更通透，调高会更接近效果图中的黑色玻璃。

App 图标位于 `RotaryClockApp/Assets.xcassets/AppIcon.appiconset`，由一张 1024×1024 主图自动生成各尺寸。第三方 App 图标不能像系统“时钟”一样持续走针；公开的备用图标 API 只能在 App 运行时切换静态图标，不适合秒级动画。实时运动保留在 App 界面和 Widget 中。

## 实验性桌面持续旋转

Widget target 通过 `ClockHandRotationKit` 桥接非公开的 `_clockHandRotationEffect`：外圈使用 `.secondHand`，内圈使用 `.minuteHand`。中间分钟秒钟使用系统 `.timer` 文本。它们由系统进程驱动，不需要 Widget Extension 每秒保持运行。

私有 `.secondHand` 每到 `00` 秒完成一圈，因此 Timeline 必须在每个整分钟边界提供新 entry 接力。当前 Provider 先生成一条立即显示的 entry，再生成未来 180 分钟、严格对齐 `xx:xx:00` 的 entry，并在 30 分钟时提前请求下一批；新旧批次有 150 分钟重叠，避免 WidgetKit 延迟刷新时在整点停成 `60:00`。不要改回以 `Date.now + 60` 为间隔的写法，也不要让刷新日期晚于最后一条 entry。Widget 根视图不能添加 `.drawingGroup()`，否则系统动画图层会被提前栅格化。App 每次打开还会调用 `reloadTimelines(ofKind:)`，用于立即清理已经耗尽的旧时间线。

该 API 并非 Apple 公开接口，可能被 App Store 审核拒绝，也可能在任意 iOS/Xcode 更新后失效。仅建议个人实验或侧载测试。依赖固定为 `ClockHandRotationKit` 1.1.0。

## 实验性透明背景

`PrivateSDK/WidgetKit.swiftmodule` 是从 Xcode 26 SDK 接口复制并补写了系统已导出、但未公开声明的 `WidgetConfiguration.isTransparent(_:)`。Widget target 通过 `SWIFT_INCLUDE_PATHS` 优先加载这份接口，最终链接的实现仍来自 iOS 自带 WidgetKit。

这不是稳定 API：它可能仅服务 Apple 内部组件或特定平台，iOS 也可能忽略标记；更换 Xcode/SDK 后接口文件需要重新生成。准备上架 App Store 时，应删除 `.isTransparent(true)`、移除 Widget target 的 `SWIFT_INCLUDE_PATHS`，并恢复公开的容器背景。

## 更新后仍显示旧的白色预览

WidgetKit 会缓存组件图库快照。请从模拟器或手机卸载旧版本 App，重新运行工程，然后删除旧组件并重新添加。必要时重启模拟器或手机以清除旧快照。

## Xcode SwiftUI Preview

- `RotaryClockApp.swift` 包含“App 预览”。选择 `RotaryClockApp` scheme 后打开 Canvas。
- `RotaryClockWidget.swift` 包含“大号组件”和“中号组件”两个 Widget Preview。预览组件时选择 `RotaryClockWidget` scheme。
- Debug 配置已设置为 `-Onone`、`ENABLE_TESTABILITY=YES` 和 `ENABLE_PREVIEWS=YES`。
- 如果 Xcode 仍显示旧的 `Not built with -Onone`，执行 **Product → Clean Build Folder**，关闭再打开 Canvas，然后点击 **Resume**。
- 可运行 `scripts/verify_xcode_previews.sh` 检查两个 scheme 的 Preview 构建设置。
