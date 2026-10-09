import SwiftUI
import AppKit
import ImageIO

/// 卡面预览：与写入 iPhone 的图片一致，只在左下角叠加卡片名称便于区分。
struct CardFace: View {
    let card: WalletCard
    let skin: Skin?

    var body: some View {
        Color.clear
            .aspectRatio(WalletCard.artworkAspectRatio, contentMode: .fit)
            .overlay { SkinArtworkView(artwork: skin?.artwork) }
            .overlay(alignment: .bottomLeading) {
                Text(card.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    // 半透明底衬保证名称在浅色皮肤上也清晰，同时尽量少遮挡卡面。
                    .background(.black.opacity(0.28), in: Capsule())
                    .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
    }
}

/// 根据皮肤来源绘制图案：内置渐变、本地导入图片或服务器图片。
struct SkinArtworkView: View {
    let artwork: Skin.Artwork?

    var body: some View {
        switch artwork {
        case .gradient(let colors):
            LinearGradient(colors: colors.map(Color.init(hex:)), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .localImage(let url):
            if let image = ThumbnailCache.shared.image(for: url) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
        case .remoteImage(let url):
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    placeholder.overlay {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(.secondary)
                    }
                    .help("皮肤图片加载失败，请检查网络连接")
                default:
                    placeholder.overlay { ProgressView().controlSize(.small) }
                }
            }
        case nil:
            placeholder
        }
    }

    private var placeholder: some View {
        Rectangle().fill(.quaternary)
    }
}

/// 本地图片缩略图缓存：导入的原图可能很大，只解码一次预览尺寸。
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, NSImage>()

    func image(for url: URL) -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1200
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        let image = NSImage(cgImage: cgImage, size: .zero)
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}

/// App 图标（来自 App 包的 AppIcon.icns）。
struct AppGlyph: View {
    var size: CGFloat = 36

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .frame(width: size, height: size)
    }
}

/// 向外扩散的脉冲圆环，用于引导和扫描页。
struct PulseRings: View {
    var color: Color = .accentColor
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(color.opacity(0.18))
                    .scaleEffect(isAnimating ? 1.35 : 0.85)
                    .opacity(isAnimating ? 0 : 0.9)
                    .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false).delay(Double(index) * 0.6), value: isAnimating)
            }
        }
        .onAppear { isAnimating = true }
    }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0
        self.init(red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255)
    }
}
