// 生成 WalletBloom 的 App 图标：五张不同皮肤的卡片像花瓣一样绽放（Wallet + Bloom）。
// 用法：swift scripts/make_icon.swift，输出 Resources/AppIcon.png 与 Resources/AppIcon.icns。
import AppKit

let canvas: CGFloat = 1024

func color(_ hex: String, _ alpha: CGFloat = 1) -> CGColor {
    let value = UInt64(hex, radix: 16) ?? 0
    return CGColor(red: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255, blue: CGFloat(value & 0xff) / 255, alpha: alpha)
}

func linearGradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
}

func renderIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    let cg = context.cgContext
    cg.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)

    // macOS 图标网格：824×824 的圆角矩形居中，四周留出阴影空间。
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: color("000000", 0.32))
    cg.addPath(tilePath)
    cg.setFillColor(color("1B1F4A"))
    cg.fillPath()
    cg.restoreGState()

    // 背景：深夜蓝到靛紫，顶部一点柔光，让彩色卡片更醒目。
    cg.saveGState()
    cg.addPath(tilePath)
    cg.clip()
    cg.drawLinearGradient(linearGradient([color("2B2F77"), color("141735")]), start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    cg.drawRadialGradient(linearGradient([color("8C7CFF", 0.45), color("8C7CFF", 0)]), startCenter: CGPoint(x: 512, y: 700), startRadius: 0, endCenter: CGPoint(x: 512, y: 700), endRadius: 460, options: [])

    // 五张卡片花瓣，颜色取自内置皮肤。卡片保持真实的 1.586:1 比例，长边沿半径方向。
    let petals: [(String, String)] = [
        ("FFB3C7", "E0628F"), // Sakura
        ("FFB070", "FF5E62"), // Sunset
        ("FFE07A", "F7A21E"), // Gold
        ("5EF0C9", "1E9BE9"), // Aurora
        ("A98BFF", "5B3FE0")  // Grape
    ]
    let center = CGPoint(x: 512, y: 506)
    let cardLength: CGFloat = 300
    let cardWidth = cardLength / 1.586
    for (index, stops) in petals.enumerated() {
        cg.saveGState()
        cg.translateBy(x: center.x, y: center.y)
        // 每片花瓣额外倾斜 16°，相邻卡片在中心附近互相叠压，形成旋转绽放的感觉。
        cg.rotate(by: CGFloat(index) * 2 * .pi / 5 + .pi / 2 + 16 * .pi / 180)
        let card = CGRect(x: -6, y: -cardWidth * 0.78, width: cardLength, height: cardWidth)
        let cardPath = CGPath(roundedRect: card, cornerWidth: 30, cornerHeight: 30, transform: nil)

        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: -6), blur: 22, color: color("000000", 0.35))
        cg.addPath(cardPath)
        cg.setFillColor(color(stops.1))
        cg.fillPath()
        cg.restoreGState()

        cg.saveGState()
        cg.addPath(cardPath)
        cg.clip()
        cg.drawLinearGradient(linearGradient([color(stops.0), color(stops.1)]), start: CGPoint(x: card.maxX, y: card.maxY), end: CGPoint(x: card.minX, y: card.minY), options: [])
        // 卡面高光，增加一点质感。
        cg.drawLinearGradient(linearGradient([color("FFFFFF", 0.28), color("FFFFFF", 0)]), start: CGPoint(x: card.midX, y: card.maxY), end: CGPoint(x: card.midX, y: card.midY), options: [])
        cg.restoreGState()

        cg.addPath(cardPath)
        cg.setStrokeColor(color("FFFFFF", 0.35))
        cg.setLineWidth(3)
        cg.strokePath()
        cg.restoreGState()
    }

    // 花蕊：白色圆点，带柔和光晕。
    cg.saveGState()
    cg.setShadow(offset: .zero, blur: 30, color: color("FFFFFF", 0.7))
    cg.setFillColor(color("FFFFFF"))
    cg.fillEllipse(in: CGRect(x: center.x - 46, y: center.y - 46, width: 92, height: 92))
    cg.restoreGState()
    cg.drawRadialGradient(linearGradient([color("FFF6D6"), color("FFFFFF", 0)]), startCenter: center, startRadius: 0, endCenter: center, endRadius: 46, options: [])

    cg.restoreGState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try renderIcon(size: points * scale).representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
try renderIcon(size: 1024).representation(using: .png, properties: [:])!.write(to: resources.appendingPathComponent("AppIcon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Created Resources/AppIcon.icns" : "iconutil failed")
