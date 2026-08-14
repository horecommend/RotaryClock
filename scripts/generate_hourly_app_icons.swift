#!/usr/bin/env swift

import AppKit
import Foundation

// MARK: - 输出位置

let fileManager = FileManager.default
let projectRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
let catalog = projectRoot
    .appendingPathComponent("RotaryClockApp", isDirectory: true)
    .appendingPathComponent("Assets.xcassets", isDirectory: true)

let canvasSize = CGSize(width: 1024, height: 1024)

// MARK: - 基础绘图工具

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func point(center: CGPoint, radius: CGFloat, index: Int) -> CGPoint {
    // 00 位于正上方，随后顺时针递增。
    let angle = CGFloat(index) / 60 * .pi * 2 - .pi / 2
    return CGPoint(
        x: center.x + cos(angle) * radius,
        y: center.y - sin(angle) * radius
    )
}

func drawLine(_ context: CGContext, from: CGPoint, to: CGPoint, width: CGFloat, color: NSColor) {
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.move(to: from)
    context.addLine(to: to)
    context.strokePath()
}

func drawCenteredText(_ text: String, in rect: CGRect, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    let measured = (text as NSString).size(withAttributes: attributes)
    let y = rect.midY - measured.height / 2
    (text as NSString).draw(
        in: CGRect(x: rect.minX, y: y, width: rect.width, height: measured.height),
        withAttributes: attributes
    )
}

func drawRing(_ context: CGContext, center: CGPoint, radius: CGFloat, labelRadius: CGFloat) {
    // 低对比度玻璃圆轨迹，让两层转盘在小尺寸下仍然可辨识。
    context.setStrokeColor(color(210, 232, 255, 0.17).cgColor)
    context.setLineWidth(5)
    context.strokeEllipse(in: CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    ))

    for index in 0..<60 {
        let emphasized = index.isMultiple(of: 5)
        let outer = point(center: center, radius: radius, index: index)
        let inner = point(
            center: center,
            radius: radius - (emphasized ? 43 : 23),
            index: index
        )
        drawLine(
            context,
            from: inner,
            to: outer,
            width: emphasized ? 10 : 6,
            color: color(255, 255, 255, emphasized ? 0.96 : 0.67)
        )
    }

    // 只保留四个方向数字，既强化转盘语义，又避免缩小时拥挤。
    for (index, label) in [(0, "00"), (15, "15"), (30, "30"), (45, "45")] {
        let labelPoint = point(center: center, radius: labelRadius, index: index)
        drawCenteredText(
            label,
            in: CGRect(x: labelPoint.x - 48, y: labelPoint.y - 35, width: 96, height: 70),
            size: 42,
            weight: .medium,
            color: color(255, 255, 255, 0.92)
        )
    }
}

func drawCapsule(_ context: CGContext, rect: CGRect) {
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
    color(4, 18, 48, 0.78).setFill()
    path.fill()
    color(226, 240, 255, 0.72).setStroke()
    path.lineWidth = 6
    path.stroke()

    // 顶部玻璃高光。
    let highlight = NSBezierPath()
    highlight.move(to: CGPoint(x: rect.minX + 55, y: rect.maxY - 24))
    highlight.curve(
        to: CGPoint(x: rect.maxX - 55, y: rect.maxY - 24),
        controlPoint1: CGPoint(x: rect.midX - 130, y: rect.maxY + 8),
        controlPoint2: CGPoint(x: rect.midX + 130, y: rect.maxY + 8)
    )
    color(255, 255, 255, 0.27).setStroke()
    highlight.lineWidth = 8
    highlight.stroke()
}

// MARK: - 单张图标

func renderIcon(hour: Int?) -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width),
        pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Unable to allocate AppIcon bitmap")
    }

    NSGraphicsContext.saveGraphicsState()
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            color(2, 17, 55).cgColor,
            color(13, 82, 164).cgColor,
            color(31, 135, 215).cgColor
        ] as CFArray,
        locations: [0, 0.55, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 50, y: 80),
        end: CGPoint(x: 940, y: 980),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    // 大面积柔和高光，模拟 iOS 26 Liquid Glass。
    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(255, 255, 255, 0.34).cgColor, color(255, 255, 255, 0).cgColor] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: 820, y: 880),
        startRadius: 0,
        endCenter: CGPoint(x: 820, y: 880),
        endRadius: 620,
        options: []
    )

    // 圆心偏左，与 Widget 的同心转盘布局一致。两圈占满画面，转盘更明显。
    let dialCenter = CGPoint(x: 265, y: 512)
    drawRing(context, center: dialCenter, radius: 475, labelRadius: 388)
    drawRing(context, center: dialCenter, radius: 315, labelRadius: 235)

    let capsule = CGRect(x: 365, y: 415, width: 610, height: 194)
    drawCapsule(context, rect: capsule)

    if let hour {
        // 备用图标只显示能够保证真实的“当前小时”；分钟交给实时小号 Widget。
        drawCenteredText(
            String(format: "%02d", hour),
            in: CGRect(x: 28, y: 338, width: 360, height: 330),
            size: 244,
            weight: .black,
            color: .white
        )

        // 胶囊内部使用小时焦点，不伪造分钟和秒钟。
        drawCenteredText(
            String(format: "%02d", hour),
            in: capsule.insetBy(dx: 96, dy: 12),
            size: 142,
            weight: .bold,
            color: .white
        )
    } else {
        // 主图标不显示假时间，用三个焦点标记表达“旋转中的读数窗口”。
        for offset in [-1, 0, 1] {
            let x = capsule.midX + CGFloat(offset) * 95
            let marker = NSBezierPath(ovalIn: CGRect(x: x - 22, y: capsule.midY - 22, width: 44, height: 44))
            (offset == 0 ? color(255, 132, 24) : color(255, 255, 255, 0.92)).setFill()
            marker.fill()
        }
    }

    // 当前读数所在的橙色水平指示线。
    drawLine(
        context,
        from: CGPoint(x: 733, y: 512),
        to: CGPoint(x: 960, y: 512),
        width: 12,
        color: color(255, 132, 24)
    )

    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to encode AppIcon PNG")
    }
    return png
}

func writeIconSet(name: String, hour: Int?) throws {
    let setURL = catalog.appendingPathComponent("\(name).appiconset", isDirectory: true)
    try fileManager.createDirectory(at: setURL, withIntermediateDirectories: true)

    let filename = "\(name)-1024.png"
    try renderIcon(hour: hour).write(to: setURL.appendingPathComponent(filename), options: .atomic)

    let contents: [String: Any] = [
        "images": [[
            "filename": filename,
            "idiom": "universal",
            "platform": "ios",
            "size": "1024x1024"
        ]],
        "info": ["author": "xcode", "version": 1]
    ]
    let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: setURL.appendingPathComponent("Contents.json"), options: .atomic)
}

try writeIconSet(name: "AppIcon", hour: nil)
for hour in 0..<24 {
    try writeIconSet(name: String(format: "AppIcon-H%02d", hour), hour: hour)
}

print("Generated primary AppIcon plus 24 hourly alternate icons.")
