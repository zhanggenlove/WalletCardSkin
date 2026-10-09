import SwiftUI

/// 导入图片后的裁剪弹窗：拖动调整位置，滑块或双指缩放调整大小，按卡面比例取景。
struct ImageCropView: View {
    let pending: WalletBloomStore.PendingImport
    let onCancel: () -> Void
    let onConfirm: (CGRect) -> Void

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1

    private let viewport = CGSize(width: 480, height: 480 / WalletCard.artworkAspectRatio)
    private let zoomRange: ClosedRange<CGFloat> = 1...4

    private var imageSize: CGSize { CGSize(width: pending.image.width, height: pending.image.height) }
    private var liveZoom: CGFloat { min(max(zoom * pinchScale, zoomRange.lowerBound), zoomRange.upperBound) }
    private var liveOffset: CGSize {
        CardArtworkCropper.clampedOffset(
            CGSize(width: offset.width + dragTranslation.width, height: offset.height + dragTranslation.height),
            imageSize: imageSize, viewport: viewport, zoom: liveZoom
        )
    }
    private var cropRect: CGRect {
        CardArtworkCropper.cropRect(imageSize: imageSize, viewport: viewport, zoom: liveZoom, offset: liveOffset)
    }
    /// 裁剪区域比卡面像素还小时，输出会被放大，提醒用户可能不清晰。
    private var isLowResolution: Bool { cropRect.width < WalletCard.artworkPixelSize.width * 0.75 }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("调整卡面图片").font(.title3.weight(.semibold))
                Text("拖动图片调整位置，用滑块或双指缩放调整大小。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            cropArea

            HStack(spacing: 10) {
                Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
                Slider(value: $zoom, in: zoomRange)
                    .onChange(of: zoom) { _, newZoom in
                        offset = CardArtworkCropper.clampedOffset(offset, imageSize: imageSize, viewport: viewport, zoom: newZoom)
                    }
                Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
                Button("重置") {
                    withAnimation(.smooth(duration: 0.25)) {
                        zoom = 1
                        offset = .zero
                    }
                }
            }
            .frame(width: viewport.width)

            Label("图片分辨率较低，卡面可能不够清晰", systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.orange)
                .opacity(isLowResolution ? 1 : 0)

            HStack {
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("使用这张图片") { onConfirm(cropRect) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: viewport.width + 48)
    }

    private var cropArea: some View {
        let scale = CardArtworkCropper.coverScale(imageSize: imageSize, viewport: viewport) * liveZoom
        return Image(decorative: pending.image, scale: 1)
            .resizable()
            .frame(width: imageSize.width * scale, height: imageSize.height * scale)
            .offset(liveOffset)
            .frame(width: viewport.width, height: viewport.height)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            .contentShape(Rectangle())
            .gesture(dragGesture.simultaneously(with: pinchGesture))
            .accessibilityLabel("卡面取景区域")
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragTranslation) { value, state, _ in state = value.translation }
            .onEnded { value in
                offset = CardArtworkCropper.clampedOffset(
                    CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height),
                    imageSize: imageSize, viewport: viewport, zoom: zoom
                )
            }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .updating($pinchScale) { value, state, _ in state = value.magnification }
            .onEnded { value in
                zoom = min(max(zoom * value.magnification, zoomRange.lowerBound), zoomRange.upperBound)
                offset = CardArtworkCropper.clampedOffset(offset, imageSize: imageSize, viewport: viewport, zoom: zoom)
            }
    }
}
