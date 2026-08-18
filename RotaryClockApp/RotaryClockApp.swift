import SwiftUI
import WidgetKit

@main
struct RotaryClockApp: App {
    init() {
        // App 被打开时主动丢弃可能已经耗尽的旧 Widget 时间线。
        // 这不是用 App 每秒驱动组件，而只是让 WidgetKit 立刻取得一批新的、
        // 带 14 小时重叠缓冲的时间线；后续仍由系统独立运行。
        WidgetCenter.shared.reloadTimelines(ofKind: "RotaryClockWidget")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

private struct ContentView: View {
    // MARK: - 固定时间视觉对比
    // 正常运行不会进入这里。仅当启动参数包含 -referenceTime 时，
    // 固定为参考图的 11:53:53，方便做截图对比。
    private var referenceDate: Date? {
        guard ProcessInfo.processInfo.arguments.contains("-referenceTime") else { return nil }
        return Calendar.current.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 14,
            hour: 11,
            minute: 53,
            second: 53
        ))
    }

    var body: some View {
        ZStack {
            // MARK: App 预览背景
            // 三个 location 控制灰色过渡到黑色的位置；white 数值控制亮度。
            // Widget 中有一份相同渐变，修改视觉时建议两边一起调整。
            LinearGradient(
                stops: [
                    .init(color: Color(white: 0.31), location: 0),
                    .init(color: Color(white: 0.10), location: 0.36),
                    .init(color: .black, location: 0.58)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let referenceDate {
                // 固定时间：仅用于视觉验收。
                RotaryClockFace(date: referenceDate, layout: .large)
                    .padding(.horizontal, 12)
                    .aspectRatio(1, contentMode: .fit)
            } else {
                // App 内每秒刷新，可实时查看圆盘动画。
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    RotaryClockFace(date: context.date, layout: .large)
                        .padding(.horizontal, 12)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview("App 预览") {
    // Xcode Canvas 中直接预览完整 App 页面。
    ContentView()
}
