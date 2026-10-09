import SwiftUI

/// 同步皮肤的模态弹窗：进度、完成后的操作提示、失败重试。
struct SyncSheet: View {
    @ObservedObject var coordinator: DefaultFlashCoordinator
    let onRetry: () -> Void

    var body: some View {
        if let job = coordinator.activeJob {
            VStack(spacing: 20) {
                CardFace(card: job.card, skin: job.skin)
                    .frame(width: 230)
                    .overlay(alignment: .topTrailing) { resultBadge(for: job.state) }
                    .padding(.top, 6)

                VStack(spacing: 6) {
                    Text(title(for: job.state))
                        .font(.title3.weight(.semibold))
                    Text(job.message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                switch job.state {
                case .preparing, .transferring:
                    VStack(spacing: 8) {
                        ProgressView(value: job.progress)
                            .animation(.easeInOut(duration: 0.4), value: job.progress)
                        HStack {
                            Text("同步期间请勿断开数据线或锁定 iPhone")
                            Spacer()
                            Text("\(Int(job.progress * 100))%").monospacedDigit()
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                case .completed:
                    VStack(spacing: 16) {
                        RefreshWalletTip()
                        Button("完成") { coordinator.dismiss() }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                            .controlSize(.large)
                    }
                case .failed:
                    HStack(spacing: 12) {
                        Button("关闭") { coordinator.dismiss() }
                            .keyboardShortcut(.cancelAction)
                        Button("重试", action: onRetry)
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                    }
                    .controlSize(.large)
                }
            }
            .padding(28)
            .frame(width: 420)
            .interactiveDismissDisabled(job.isRunning)
            .animation(.smooth(duration: 0.3), value: job.state)
        }
    }

    private func title(for state: FlashJob.State) -> String {
        switch state {
        case .preparing, .transferring: return "正在同步到 iPhone"
        case .completed: return "同步完成"
        case .failed: return "同步失败"
        }
    }

    @ViewBuilder
    private func resultBadge(for state: FlashJob.State) -> some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
                .font(.system(size: 34))
                .offset(x: 12, y: -12)
                .transition(.scale.combined(with: .opacity))
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
                .font(.system(size: 34))
                .offset(x: 12, y: -12)
                .transition(.scale.combined(with: .opacity))
        case .preparing, .transferring:
            EmptyView()
        }
    }
}

/// 同步完成后提示用户重启钱包 App，否则钱包会继续显示内存中的旧卡面。
private struct RefreshWalletTip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("还差一步就能看到新卡面", systemImage: "lightbulb.fill")
                .font(.headline)
                .symbolRenderingMode(.multicolor)
            VStack(alignment: .leading, spacing: 4) {
                Text("1. 在 iPhone 上从屏幕底部上滑并停顿，打开后台 App 列表（有主屏幕按钮的机型：连按两下主屏幕按钮）")
                    .fixedSize(horizontal: false, vertical: true)
                Text("2. 找到「钱包」，向上滑动将其关闭")
                Text("3. 重新打开钱包，即可看到新卡面（仍是旧卡面时，可重启 iPhone）")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
