import CarPlay
import SwiftUI
import UIKit

/// 导航类 CarPlay 场景。
///
/// Maps entitlement 才会让 CarPlay 在连接时提供 `CPWindow`。当前是研究版纯时钟
/// 画面；接入真实导航产品时，窗口主内容应恢复为地图和路线。
@MainActor
final class CarPlayClockSceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private weak var interfaceController: CPInterfaceController?
    private weak var carWindow: CPWindow?

    /// Maps 场景连接时，CarPlay 同时提供模板控制器和可绘制地图内容的窗口。
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        carWindow = window

        // 车机系统使用这个模板管理导航栏、路线引导与语音控制等原生导航 UI。
        let mapTemplate = CPMapTemplate()
        interfaceController.setRootTemplate(mapTemplate, animated: false, completion: nil)

        // 研究版：CPWindow 直接展示同一套转盘时钟，不再放置 MapKit 地图。
        window.rootViewController = CarPlayClockWindowViewController()
    }

    /// 导航场景断开时释放引用，避免旧窗口残留在内存中。
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        window.rootViewController = nil
        carWindow = nil
        self.interfaceController = nil
    }
}

/// 在 CarPlay 的 CPWindow 内全屏承载转盘时钟。
///
/// 注意：这是用于验证布局和系统合成动画的研究版。生产导航模式应以地图为主内容，
/// 并把时钟改回非交互的辅助叠层。
@MainActor
private final class CarPlayClockWindowViewController: UIViewController {
    /// CarPlay Simulator 有时只合成 SwiftUI 宿主视图的第一帧。因此把 SwiftUI
    /// 时钟交给原生 Canvas 重绘，最终提交给 CPWindow 的始终是 UIKit 图层。
    private let clockCanvas = CarPlayClockCanvasView()
    private var displayLink: CADisplayLink?
    private var displayedSecond = -1

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        // 纯展示层不应响应点击，避免 CarPlay 将触摸解释为模板手势。
        view.isUserInteractionEnabled = false

        clockCanvas.translatesAutoresizingMaskIntoConstraints = false
        clockCanvas.backgroundColor = .black
        clockCanvas.isOpaque = true
        clockCanvas.isUserInteractionEnabled = false
        view.addSubview(clockCanvas)
        NSLayoutConstraint.activate([
            // CarPlay 的左侧系统栏会浮在 App 内容上。遵守安全区，避免小时首位
            // 被 Home/应用栏遮住。
            clockCanvas.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            clockCanvas.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            clockCanvas.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            clockCanvas.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        refreshClock()
        startDisplayLink()
    }

    deinit {
        displayLink?.invalidate()
    }

    /// 连接初始时立即提交当前时间，避免等待下一帧才出现读数。
    private func refreshClock() {
        clockCanvas.displayedDate = Date()
    }

    /// 绑定 CarPlay 外接屏的刷新节奏。普通 `Timer` 在纯 CPWindow 场景可能继续
    /// 回调却不被外接合成器采样；`CADisplayLink` 会随显示帧运行。虽然它每帧回调，
    /// 但只有秒数变化时才重绘，成本仍为每秒一次。
    private func startDisplayLink() {
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func displayLinkDidTick() {
        let now = Date()
        let currentSecond = Int(now.timeIntervalSinceReferenceDate.rounded(.down))
        guard currentSecond != displayedSecond else {
            return
        }
        displayedSecond = currentSecond
        clockCanvas.displayedDate = now
    }

}

/// 以 UIKit 的 `draw(_:)` 向 CarPlay 外接屏提交绘制命令。
@MainActor
private final class CarPlayClockCanvasView: UIView {
    var displayedDate = Date() {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        // 每秒只生成一次 400×240 左右的轻量位图；SwiftUI 继续负责复用现有布局。
        let content = ZStack {
            Color.black
            RotaryClockFace(date: displayedDate, layout: .carPlay)
        }
        .preferredColorScheme(.dark)
        .frame(width: bounds.width, height: bounds.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = contentScaleFactor
        renderer.uiImage?.draw(in: bounds)
    }
}
