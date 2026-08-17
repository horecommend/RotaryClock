import SwiftUI

#if ROTARY_WIDGET
// 实验版私有 API 桥接库。仅 Widget target 会导入，App target 不依赖它。
import ClockHandRotationKit
#endif

// MARK: - 组件尺寸类型

/// Widget 的布局类型。
/// 中号组件高度较矮，因此部分字号和间距会使用 compact 参数。
enum RotaryClockLayout {
    case medium
    case large
}

struct RotaryClockFace: View {
    /// 当前要显示的时间。Widget 传入时间线时间，App 预览传入实时或固定测试时间。
    let date: Date
    let layout: RotaryClockLayout

    // 从同一个 Calendar 读取时、分、秒，避免三个圆盘出现时间不一致。
    private var calendar: Calendar { .current }
    private var hour: Int { calendar.component(.hour, from: date) }
    private var minute: Int { calendar.component(.minute, from: date) }
    private var second: Int { calendar.component(.second, from: date) }

    // MARK: 连续旋转步数
    // 不能直接拿 0...59 做动画，否则 59 → 00 时可能反向转动近一整圈。
    // 连续步数永远递增，保证秒盘每秒前进一格，分钟盘每分钟前进一格。
    private var dayOrdinal: Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }
    private var continuousMinute: Int {
        dayOrdinal * 24 * 60 + hour * 60 + minute
    }
    private var continuousSecond: Int {
        continuousMinute * 60 + second
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let compact = layout == .medium
            let hourText = String(format: "%02d", hour)

            // MARK: 整体缩放基准
            // 所有字号、半径和间距都乘以 unit。
            // 想整体放大/缩小界面，可先调整这里的 2.05，或调整下面各参数的倍率。
            let unit = min(size.width, compact ? size.height * 2.05 : size.height)

            // MARK: 同心转盘圆心与读数焦点（最常用的调参位置）
            // x 是组件宽度的百分比：变小向左移动，变大向右移动。
            // y 固定使用 size.height / 2，在任意 Widget 尺寸中都保持上下居中。
            // 两个转盘必须共用这一个圆心，才能形成同心转盘。
            // 修改 dialCenter.x 会同时水平移动分钟盘和秒盘，不会破坏同心关系。
            let dialCenter = CGPoint(
                x: size.width * (compact ? 0.05 : 0.05),
                y: size.height / 2
            )

            // 读数焦点决定“分钟－秒”胶囊的位置。
            // compact 的第一个倍率专门控制小号横向 Widget：减小会整体向左，
            // 增大会整体向右；这里只移动胶囊和分秒文字，不移动日期。
            // y 必须直接使用 dialCenter.y，保证圆盘中心和所有当前数值在同一水平线上。
            let focusCenter = CGPoint(
                x: dialCenter.x + size.width * (compact ? 0.40 : 0.40),
                y: dialCenter.y
            )

            // 小时与转盘使用原设计的同一水平基准，不额外右移。
            // 之前只剩“时”是中文日期格式附加字词造成的，不是坐标问题。
            let hourCenterX = dialCenter.x + 30

            ZStack {
                dialLayer(
                    size: size,
                    dialCenter: dialCenter,
                    unit: unit
                )
                    // 只显示日期左侧的转盘内容，避免刻度穿过日期文字。
                    // 0.20 增大：圆盘向右显示更多；减小：更早被裁切。
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: min(size.width, focusCenter.x + unit * 0.20))
                    }

                // MARK: 中央大号“当前小时”
                // 这是设计图中最大的数字，不属于任何转盘。
                // 字号倍率：中号 0.20、大号 0.18。
                // position 的 x 倍率控制小时文字左右位置。
                // 透明 Widget 宿主目前会丢弃小时的实时 currentDate Text，或按
                // 中文 locale 追加“时”。小时采用当前 timeline entry 的数字值；
                // Provider 每分钟提供条目，所以整点时会变为下一小时。分秒仍使用
                // 系统实时 currentDate，保证秒级更新与 59:59 → 00:00 循环。
                HStack(spacing: -unit * (compact ? 0.018 : 0.014)) {
                    // 两个数字分别排版，各自保留完整字形边界；HStack 的负
                    // spacing 只让两个边界互相靠近，不会裁掉第二位右侧。
                    Text(String(hourText.prefix(1)))
                    Text(String(hourText.suffix(1)))
                }
                    .font(.system(size: unit * (compact ? 0.20 : 0.22), weight: .black, design: .rounded))
                    .monospacedDigit()
                    .fixedSize()
                    .foregroundStyle(.white)
                    .position(x: hourCenterX, y: focusCenter.y)
                    .zIndex(2)

                // 胶囊同时显示当前分钟和当前秒，例如“40－05”。
                currentMinuteAndSecond(unit: unit, compact: compact)
                    .position(focusCenter)

                // MARK: 右侧日期
                // x 的 0.82/0.79 控制日期左右位置；y 与圆盘中心保持一致。
                dateBlock(unit: unit, compact: compact)
                    .position(
                        x: size.width * (compact ? 0.82 : 0.79),
                        y: focusCenter.y
                    )
                    .zIndex(2)
            }
            .frame(width: size.width, height: size.height)
            // 两个大圆会越过组件边缘，必须裁切才能得到参考图效果。
            .clipped()
            // 不要在 Widget target 使用 drawingGroup：它会把带有私有
            // clockHandRotationEffect 的圆盘提前栅格化，SpringBoard 最终只拿到
            // 静态位图，无法继续驱动秒盘和分钟盘的系统合成动画。
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityTime)
        }
    }

    @ViewBuilder
    private func dialLayer(
        size: CGSize,
        dialCenter: CGPoint,
        unit: CGFloat
    ) -> some View {
        ZStack {
            // MARK: 最外层“秒盘”
            // value 必须使用 second：秒数每变化一次，最外圈前进一步。
            // radius 0.58：改大后圆弧更平、更靠近边缘；改小后圆形更完整。
            // anchorAngle 0：当前秒位于圆盘正右方；改它可整体旋转秒盘。
            DialRing(
                value: second,
                rotationStep: continuousSecond,
                rotationPeriod: .second,
                maximum: 60,
                radius: unit * 0.53,
                unit: unit,
                labelEvery: 5,
                anchorAngle: 0
            )
                // 秒盘和分钟盘必须使用同一个 dialCenter。
                .position(dialCenter)

            // MARK: 内层“分钟盘”
            // value 必须使用 minute；胶囊中的数字也读取同一个 minute。
            // 不传 labelWindow，完整显示 00、05、10……55 共 12 个分钟数值。
            DialRing(
                value: minute,
                rotationStep: continuousMinute,
                rotationPeriod: .minute,
                maximum: 60,
                radius: unit * 0.36,
                unit: unit,
                labelEvery: 5,
                // 0 表示当前分钟位于正右方，与中间框选值处于同一水平线。
                anchorAngle: 0
            )
            // 与上面的秒盘共用圆心，只通过 radius 区分内外圈。
            .position(dialCenter)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - 当前分钟与秒钟胶囊

    private func currentMinuteAndSecond(unit: CGFloat, compact: Bool) -> some View {
        // 两个圆盘半径分别是 0.36 / 0.53 unit，所以它们与水平中心线的
        // 两个交点相距 0.17 unit。分钟和秒钟的文字中心使用同一间距，
        // 视觉上就会分别落在内圈、外圈的弧线中心，而不会挤在胶囊中央。
        let readoutCenterSeparation = unit * 0.17
        let capsuleWidth = unit * (compact ? 0.31 : 0.35)
        let capsuleHeight = unit * (compact ? 0.105 : 0.103)

        return ZStack {
            // 玻璃只作用在独立背景层。不要把 glassEffect 加到整个 ZStack，
            // 否则 Widget 的系统动态 Timer 文字也会进入玻璃合成层，真机/模拟器
            // 桌面可能只画出胶囊而看不到分秒。
            // 深色底与玻璃必须是两个独立层。glassEffect 会接管其宿主视图
            // 的绘制；如果把黑色 fill 和它写在同一个 Shape 上，Widget
            // 合成器可能只保留玻璃、丢掉黑色填充。
            Capsule()
                .fill(.black.opacity(0.46))

            Capsule()
                .fill(.clear)
                .glassEffect(
                    .regular
                        // 调低会更通透，调高会让玻璃色调更深。
                        .tint(.black.opacity(0.42))
                        .interactive(false),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        // 玻璃高光之外保留一条细边，贴近效果图轮廓。
                        .stroke(.white.opacity(0.58), lineWidth: max(1.0, unit * 0.0015))
                }

#if ROTARY_WIDGET
            // MARK: iOS 26 实时“当前分钟:秒钟”
            // 不能用 `timerInterval`：它显示的是范围内的累计时长，会从
            // 59:59 继续到 60:00、65:00，且范围结束时停止。TimeDataSource
            // 由 Widget 宿主持续提供真实当前时间，不依赖 Extension 被秒级唤醒；
            // Date.FormatStyle 会按钟表语义自动从 59:59 回到 00:00，并保留两位
            // 分钟与两位秒钟，例如 08:05。
            Text(
                .currentDate,
                format: .dateTime.minute(.twoDigits).second(.twoDigits)
            )
            .font(.system(size: unit * (compact ? 0.085 : 0.085), weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            // 胶囊空间不足时让系统动态文字一起轻微缩小，但不裁切它。
            .minimumScaleFactor(0.72)
            .frame(
                width: capsuleWidth,
                height: capsuleHeight,
                alignment: .center
            )
            // 系统动态时钟的可见字形会略微偏左，整体向右微调。
            .offset(x: unit *  (compact ? 0.03 : 0.05))

#else
            // App 内由 TimelineView 每秒传入新时间，可以直接分别定位。
            Text(String(format: "%02d", minute))
                .font(.system(size: unit * (compact ? 0.112 : 0.092), weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .position(
                    x: capsuleWidth / 2 - readoutCenterSeparation / 2,
                    y: capsuleHeight / 2
                )

            Text(String(format: "%02d", second))
                .font(.system(size: unit * (compact ? 0.078 : 0.064), weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .position(
                    x: capsuleWidth / 2 + readoutCenterSeparation / 2,
                    y: capsuleHeight / 2
                )
#endif
        }
        .frame(width: capsuleWidth, height: capsuleHeight)
        .zIndex(3)
    }

    // MARK: - 公历与农历

    private func dateBlock(unit: CGFloat, compact: Bool) -> some View {
        VStack(spacing: unit * (compact ? 0.018 : 0.024)) {
            Text(solarDate)
            Text(lunarDate)
        }
        .font(.system(size: unit * (compact ? 0.038 : 0.032), weight: .regular, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.62)
        // 日期区域宽度；文字被压缩时可适当增大此值。
        .frame(width: unit * (compact ? 0.34 : 0.31))
    }

    private var solarDate: String {
        let formatter = DateFormatter()
        // 使用简体中文，确保星期显示为“星期五”而不是英文。
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "MM月dd日  EEEE"
        return formatter.string(from: date)
    }

    private var lunarDate: String {
        // Foundation 自带中国农历，无需联网或第三方依赖。
        var chinese = Calendar(identifier: .chinese)
        chinese.locale = Locale(identifier: "zh_Hans_CN")
        let month = chinese.component(.month, from: date)
        let day = chinese.component(.day, from: date)
        let monthNames = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
        return "\(monthNames[max(0, min(month - 1, 11))])月  \(Self.lunarDay(day))"
    }

    private static func lunarDay(_ day: Int) -> String {
        let names = [
            "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
        ]
        return names[max(0, min(day - 1, names.count - 1))]
    }

    private var accessibilityTime: String {
        // VoiceOver 会一次读出完整时间和日期，而不是逐个读取转盘刻度。
        "\(hour)点\(minute)分\(second)秒，\(solarDate)，\(lunarDate)"
    }
}

private enum DialRotationPeriod {
    case second
    case minute

#if ROTARY_WIDGET
    /// 把项目内的语义类型转换为桥接库提供的私有时钟周期。
    var clockHandPeriod: ClockHandRotationPeriod {
        switch self {
        case .second: .secondHand
        case .minute: .minuteHand
        }
    }
#endif
}

private struct DialRing: View {
    /// 当前值：外盘传入秒，内盘传入分钟。
    let value: Int
    /// 连续递增的旋转步数，专门避免 59 → 00 时倒转一整圈。
    let rotationStep: Int
    /// 此圆盘由系统秒钟周期还是分钟周期驱动。
    let rotationPeriod: DialRotationPeriod
    /// 一圈总刻度数，目前统一为 60。
    let maximum: Int
    /// 圆盘半径。
    let radius: CGFloat
    /// 整体缩放基准。
    let unit: CGFloat
    /// 每隔多少格显示一个大刻度和数字；5 表示 00、05、10……
    let labelEvery: Int
    /// 只显示当前值附近的标签范围；nil 表示显示整圈标签。
    var labelWindow: ClosedRange<Int>? = nil
    /// 整个转盘的相位偏移角度；负数通常向逆时针偏移。
    var anchorAngle: Double = 0

    var body: some View {
        // 小圆盘按半径自动减小标签内缩和字号，避免数字挤在一起。
        let labelInset = min(unit * 0.055, radius * 0.25)
        let labelFontSize = min(unit * 0.060, radius * 0.22)

        let ring = ZStack {
            ForEach(0..<maximum, id: \.self) { index in
                // Widget 由系统从静态零点开始旋转；App 则使用连续步数自行计算角度。
                let angle = anchorAngle + Double(renderRotationStep - index) * (360 / Double(maximum))
                let emphasized = index.isMultiple(of: labelEvery)

                Capsule()
                    .fill(.white.opacity(emphasized ? 0.92 : 0.72))
                    .frame(
                        // 大刻度长度 0.034，小刻度长度 0.019；可在这里调刻度疏密感。
                        width: unit * (emphasized ? 0.034 : 0.019),
                        height: max(1.2, unit * 0.0024)
                    )
                    .offset(x: radius)
                    .rotationEffect(.degrees(angle))

                if emphasized && isLabelVisible(index) {
                    Text(label(for: index))
                        .font(.system(size: labelFontSize, weight: .regular, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.94))
                        .offset(x: radius - labelInset)
                        .rotationEffect(.degrees(angle))
                }
            }
        }

#if ROTARY_WIDGET
        // 实验性私有效果：由 SpringBoard 驱动，即使 Widget Extension 休眠仍能旋转。
        ring.clockHandRotationEffect(
            period: rotationPeriod.clockHandPeriod,
            in: .current,
            anchor: .center
        )
#else
        // 数值变化时的转盘过渡时长。设为 0 可取消动画。
        ring.animation(.linear(duration: 0.22), value: rotationStep)
#endif
    }

    /// Widget 的私有效果会自己根据系统时间旋转，所以基础刻度必须保持在零点。
    private var renderRotationStep: Int {
#if ROTARY_WIDGET
        0
#else
        rotationStep
#endif
    }

    private func label(for index: Int) -> String {
        return String(format: "%02d", index)
    }

    private func isLabelVisible(_ index: Int) -> Bool {
        guard let labelWindow else { return true }
        // 把跨越 59→00 的距离归一化到 -30...29，方便使用 labelWindow 筛选。
        let rawDistance = (index - value + maximum) % maximum
        let signedDistance = rawDistance > maximum / 2 ? rawDistance - maximum : rawDistance
        return labelWindow.contains(signedDistance)
    }
}
