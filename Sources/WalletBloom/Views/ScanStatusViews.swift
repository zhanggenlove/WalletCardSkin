import SwiftUI

struct ScanningView: View {
    let progress: Double
    let duration: TimeInterval
    let onCancel: () -> Void

    private var remainingSeconds: Int { max(Int((1 - progress) * duration), 0) }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                PulseRings().frame(width: 120, height: 120)
                Image(systemName: "wallet.pass")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse)
            }

            VStack(spacing: 6) {
                Text("正在扫描 Wallet 卡片…")
                    .font(.title2.weight(.semibold))
                Text("请在 iPhone 上保持钱包 App 打开，不要断开数据线")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 280)
                Text(remainingSeconds > 0 ? "预计还需 \(remainingSeconds) 秒" : "正在整理结果…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Button("取消扫描", action: onCancel)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NoCardsView: View {
    @ObservedObject var store: WalletBloomStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label("没有扫描到卡片", systemImage: "creditcard")
        } description: {
            Text("看起来你的钱包里还没有添加任何卡片。请在 iPhone 上打开「钱包」App，点击右上角「+」添加银行卡或交通卡后，再重新扫描。")
        } actions: {
            HStack(spacing: 12) {
                Button("重新扫描") { store.startScan() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                Button("查看连接步骤") { store.showOnboarding() }
            }
            .controlSize(.large)

            HStack(spacing: 4) {
                Text("钱包里已有卡片却仍无法识别？")
                Button("联系技术支持") { openSupportMail() }
                    .buttonStyle(.link)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.top, 6)
        }
    }

    private func openSupportMail() {
        let body = "设备：\(store.device.map { "\($0.name) \($0.model) \($0.systemVersion)" } ?? "未连接")\n问题：扫描不到钱包中的卡片"
        if let url = SupportContact.mailURL(subject: "WalletBloom 无法识别卡片", body: body) { openURL(url) }
    }
}

struct ScanFailedView: View {
    @ObservedObject var store: WalletBloomStore
    let message: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("扫描遇到问题")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
            }
        } description: {
            Text("无法读取钱包卡片，可能是设备兼容性或系统版本问题。请尝试重新连接设备；若问题持续，请联系技术支持。")
        } actions: {
            Text(message)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(maxWidth: 460)

            HStack(spacing: 12) {
                Button("重试") { Task { await store.retry() } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                Button("联系技术支持") { openSupportMail() }
            }
            .controlSize(.large)
            .padding(.top, 4)

            Text("技术支持：\(SupportContact.email)")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
    }

    private func openSupportMail() {
        let body = "设备：\(store.device.map { "\($0.name) \($0.model) \($0.systemVersion)" } ?? "未连接")\n错误信息：\(message)"
        if let url = SupportContact.mailURL(subject: "WalletBloom 扫描故障", body: body) { openURL(url) }
    }
}
