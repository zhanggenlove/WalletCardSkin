import SwiftUI
import AppKit

/// 隐私与安全说明。这里的每一条都必须和实际行为一致，修改功能时同步检查。
struct PrivacyView: View {
    let libraryDirectory: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                Text("你的卡片信息是安全的")
                    .font(.title2.weight(.bold))
                Text("WalletBloom 只更换钱包里卡片的外观，不接触任何支付信息。")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 18) {
                PrivacyRow(symbol: "lock.shield.fill", tint: .blue, title: "读不到支付信息", detail: "Apple Pay 的支付凭证保存在 iPhone 的安全芯片中，实体卡号也不会存储在 iPhone 上。WalletBloom 无法读取这些信息，也从不尝试读取。")
                PrivacyRow(symbol: "network.slash", tint: .orange, title: "不上传任何数据", detail: "识别卡片、同步皮肤都通过数据线在本机完成，不经过任何服务器，也不收集使用统计。App 联网只用于检查更新，不会发送任何卡片或设备信息。")
                PrivacyRow(symbol: "creditcard.fill", tint: .green, title: "不影响刷卡", detail: "只替换卡面显示的图片，不改动支付凭证，Apple Pay 照常使用。")
                PrivacyRow(symbol: "internaldrive.fill", tint: .gray, title: "数据只留在这台 Mac 上", detail: "只保存用于区分卡片的文件标识（不是卡号）和你的皮肤选择，删除 App 数据文件夹即可全部清除。")
            }
            .padding(.horizontal, 32)

            HStack {
                if FileManager.default.fileExists(atPath: libraryDirectory.path) {
                    Button("在访达中显示数据") {
                        NSWorkspace.shared.activateFileViewerSelecting([libraryDirectory])
                    }
                }
                Spacer()
                Button("好的") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .frame(width: 480)
    }
}

private struct PrivacyRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
