import AppKit
import ImageIO

/// 导入图片的裁剪：按卡面比例取景，输出 1536×969 的 PNG。
enum CardArtworkCropper {
    /// 读取图片并应用 EXIF 方向；长边限制在 4096 像素，足够放大裁剪且不占用过多内存。
    static func loadImage(at url: URL) -> CGImage? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 4096
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    /// 图片铺满取景框（cover）时的缩放比例。
    static func coverScale(imageSize: CGSize, viewport: CGSize) -> CGFloat {
        max(viewport.width / imageSize.width, viewport.height / imageSize.height)
    }

    /// 把偏移限制在图片仍能铺满取景框的范围内。
    static func clampedOffset(_ offset: CGSize, imageSize: CGSize, viewport: CGSize, zoom: CGFloat) -> CGSize {
        let scale = coverScale(imageSize: imageSize, viewport: viewport) * zoom
        let maxX = max((imageSize.width * scale - viewport.width) / 2, 0)
        let maxY = max((imageSize.height * scale - viewport.height) / 2, 0)
        return CGSize(width: min(max(offset.width, -maxX), maxX), height: min(max(offset.height, -maxY), maxY))
    }

    /// 取景框内可见区域对应的图片像素区域（左上角为原点）。
    static func cropRect(imageSize: CGSize, viewport: CGSize, zoom: CGFloat, offset: CGSize) -> CGRect {
        let scale = coverScale(imageSize: imageSize, viewport: viewport) * zoom
        let offset = clampedOffset(offset, imageSize: imageSize, viewport: viewport, zoom: zoom)
        let width = viewport.width / scale
        let height = viewport.height / scale
        let x = imageSize.width / 2 - offset.width / scale - width / 2
        let y = imageSize.height / 2 - offset.height / scale - height / 2
        return CGRect(x: x, y: y, width: width, height: height).integral.intersection(CGRect(origin: .zero, size: imageSize))
    }

    /// 把裁剪区域渲染成 Wallet 卡面尺寸的 PNG。
    static func renderPNG(_ image: CGImage, cropRect: CGRect) throws -> Data {
        guard let cropped = image.cropping(to: cropRect) else { throw WalletError.invalidAsset }
        let width = Int(WalletCard.artworkPixelSize.width)
        let height = Int(WalletCard.artworkPixelSize.height)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw WalletError.invalidAsset }
        context.interpolationQuality = .high
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let output = context.makeImage(),
              let data = NSBitmapImageRep(cgImage: output).representation(using: .png, properties: [:]) else { throw WalletError.invalidAsset }
        return data
    }
}
