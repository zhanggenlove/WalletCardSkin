import AppKit

/// 把任意来源的皮肤变成一个可以交给 AirCard backend 的本地图片文件。
enum SkinArtworkExporter {
    struct ExportedFile {
        let url: URL
        let isTemporary: Bool

        func cleanUp() {
            if isTemporary { try? FileManager.default.removeItem(at: url) }
        }
    }

    static func export(_ skin: Skin) async throws -> ExportedFile {
        switch skin.artwork {
        case .gradient(let colors):
            return ExportedFile(url: try BuiltInSkinRenderer.render(colors: colors), isTemporary: true)
        case .localImage(let url):
            return ExportedFile(url: url, isTemporary: false)
        case .remoteImage(let url):
            let (downloadedURL, response) = try await URLSession.shared.download(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw WalletError.unsupported("皮肤下载失败（HTTP \(http.statusCode)）")
            }
            let fileExtension = url.pathExtension.isEmpty ? "png" : url.pathExtension
            let destination = temporaryURL(extension: fileExtension)
            try FileManager.default.moveItem(at: downloadedURL, to: destination)
            return ExportedFile(url: destination, isTemporary: true)
        }
    }

    fileprivate static func temporaryURL(extension fileExtension: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("walletbloom-\(UUID().uuidString).\(fileExtension)")
    }
}

enum BuiltInSkinRenderer {
    static func render(colors: [String]) throws -> URL {
        let width = Int(WalletCard.artworkPixelSize.width)
        let height = Int(WalletCard.artworkPixelSize.height)
        // 直接在固定像素的位图上绘制，避免 NSImage.lockFocus 在 Retina 屏上输出 2 倍尺寸的图片。
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw WalletError.invalidAsset }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        // 与 App 内预览（左上 → 右下的线性渐变）保持一致，不叠加任何文字。
        NSGradient(colors: colors.map { NSColor(hex: $0) })?.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -32)
        NSGraphicsContext.restoreGraphicsState()

        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw WalletError.invalidAsset }
        let url = SkinArtworkExporter.temporaryURL(extension: "png")
        try data.write(to: url, options: .atomic)
        return url
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0
        self.init(red: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255, blue: CGFloat(value & 0xff) / 255, alpha: 1)
    }
}
