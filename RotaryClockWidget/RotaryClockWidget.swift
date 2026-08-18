import SwiftUI
import WidgetKit

struct RotaryClockEntry: TimelineEntry {
    /// WidgetKit 时间线中的展示时间。
    let date: Date
}

// MARK: - Widget 时间线

struct RotaryClockProvider: TimelineProvider {
    // 添加组件、重装或切换透明外观时，系统可能先显示 placeholder。
    // 根视图使用了 unredacted()，所以这里必须给当前真实时间，不能写死
    // 测试日期；否则用户会直接看到假时间和假日期。
    func placeholder(in context: Context) -> RotaryClockEntry {
        RotaryClockEntry(date: .now)
    }

    // Xcode Preview 和组件图库快照使用当前时间。
    func getSnapshot(in context: Context, completion: @escaping (RotaryClockEntry) -> Void) {
        completion(RotaryClockEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RotaryClockEntry>) -> Void) {
        let now = Date.now
        let calendar = Calendar.autoupdatingCurrent
        let hourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now

        // MARK: 时间线滚动窗口（小时与日期刷新）
        // WidgetKit 的 `.after` 不是准点刷新承诺，只表示从该时刻开始系统
        // 可以请求新时间线。必须在请求刷新以后继续保留一段未来条目，
        // 让新旧批次重叠；否则系统晚几分钟唤醒扩展，旧批次已经耗尽，
        // 静态小时会停住，有限区间 Timer 也会停在 60:00。
        //
        // 每批覆盖 26 小时、12 小时后请求下一批。因此正常跨越午夜时，
        // 旧批次仍至少有 14 小时的未来条目可用，不会让小时/日期停在前一天。
        // 想调节时必须保持两者差值 >= 1。
        let timelineHorizonHours = 26
        let reloadAfterHours = 12

        // 第 0 条立即显示当前时间；后续条目严格对齐到整点。
        // 转盘本身由 SpringBoard 的 clockHandRotationEffect 继续驱动，
        // 不依赖每分钟切换 entry。Timeline 只负责需要稳定文字渲染的
        // 小时、日期、星期与农历，从而将每批条目由 1561 降为 27。
        let entries = [RotaryClockEntry(date: now)] + (1...timelineHorizonHours).map { offset in
            RotaryClockEntry(
                date: hourStart.addingTimeInterval(Double(offset * 60 * 60))
            )
        }

        // 提前刷新而不是等到最后一条用完；旧条目会一直兜底到新批次到达。
        let reloadDate = hourStart.addingTimeInterval(Double(reloadAfterHours * 60 * 60))
        completion(Timeline(entries: entries, policy: .after(reloadDate)))
    }
}

struct RotaryClockWidgetView: View {
    /// 系统当前要求渲染的组件尺寸。
    @Environment(\.widgetFamily) private var family
    let entry: RotaryClockEntry

    var body: some View {
        // 转盘由实验性的 clockHandRotationEffect 在系统进程中驱动，
        // 不再依赖 Widget Extension 每秒被唤醒。
        RotaryClockFace(
            date: entry.date,
            layout: layout
        )
        // iOS 26 切换“透明”桌面外观时，Widget 宿主可能临时给内容
        // 注入 placeholder redaction。时钟不包含隐私数据，明确取消它，
        // 否则所有 Text 会变成截图中的圆角占位块。
        .unredacted()
        // 整个时钟都不加入系统的强调色组，避免透明/色调外观把它解释成
        // 单色蒙版。`widgetAccentedRenderingMode(.fullColor)` 只能用于 Image，
        // 不能用于包含 Text 和 Shape 的根 View。
        .widgetAccentable(false)
        .containerBackground(for: .widget) {
            // MARK: Widget 实验性透明背景
            // 这里只绘制透明像素；是否保留系统卡片由下面的私有
            // WidgetConfiguration.isTransparent(true) 标记决定。
            Color.clear
        }
        .preferredColorScheme(.dark)
    }

    /// 三种组件尺寸共用同一套同心转盘；小号仅使用更紧凑的排版比例。
    private var layout: RotaryClockLayout {
        switch family {
        case .systemSmall:
            .small
        case .systemMedium:
            .medium
        default:
            .large
        }
    }
}

@main
struct RotaryClockWidget: Widget {
    /// Widget 的唯一标识；发布后不要随意修改，否则系统会把它视为新组件。
    let kind = "RotaryClockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RotaryClockProvider()) { entry in
            RotaryClockWidgetView(entry: entry)
        }
        .configurationDisplayName("转盘时钟")
        .description("实验性透明背景的同心转盘时钟。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // 关闭系统默认内边距，让越界圆盘贴到组件边缘。
        .contentMarginsDisabled()
        // 保留公开 API 标记：系统需要移除背景时仍能采用标准路径。
        .containerBackgroundRemovable(true)
        // MARK: 私有 Swift ABI 实验
        // 该声明来自 PrivateSDK 中补写的 WidgetKit.swiftinterface；
        // 实现仍由系统 WidgetKit 提供。删掉此行即可退出私有透明实验。
        .isTransparent(true)
    }
}

#Preview("大号组件", as: .systemLarge) {
    // Xcode Canvas：大号 Widget。
    RotaryClockWidget()
} timeline: {
    RotaryClockEntry(date: .now)
}

#Preview("中号组件", as: .systemMedium) {
    // Xcode Canvas：中号 Widget。
    RotaryClockWidget()
} timeline: {
    RotaryClockEntry(date: .now)
}

#Preview("小号组件", as: .systemSmall) {
    // Xcode Canvas：小号 Widget（三行日期信息仍会显示）。
    RotaryClockWidget()
} timeline: {
    RotaryClockEntry(date: .now)
}
