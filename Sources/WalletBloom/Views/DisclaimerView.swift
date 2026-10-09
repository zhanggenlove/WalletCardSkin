import SwiftUI
import AppKit

/// 免责声明。首次启动时必须同意才能继续；之后可在「帮助」菜单中随时查看。
/// 修改条款内容时请把 `version` 加 1，已同意旧版本的用户会被要求重新确认。
struct DisclaimerView: View {
    static let version = 2

    enum Mode {
        case agreement
        case reference
    }

    let mode: Mode
    var onAgree: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 34))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange)
                Text("使用须知")
                    .font(.title2.weight(.bold))
                Text(mode == .agreement ? "开始使用前，请花一分钟阅读以下内容。" : "WalletBloom 免责声明")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DisclaimerSection(title: "第三方工具", text: "WalletBloom 是独立开发的第三方工具，与 Apple Inc. 以及任何银行、发卡机构、卡组织均无关联，也未获得其授权或认可。Apple、Apple Pay、iPhone、钱包是 Apple Inc. 的商标。")
                    DisclaimerSection(title: "修改了什么", text: "WalletBloom 通过数据线修改 iPhone 钱包中卡片的显示图片，不会改动支付凭证。这项修改不是 Apple 官方提供的功能。")
                    DisclaimerSection(title: "无法恢复原卡面", text: RestoreNotice.detail, isEmphasized: true)
                    DisclaimerSection(title: "可能出现的情况", text: "更新 iOS 或钱包重新同步卡片后，卡面可能被系统还原；个别系统版本上卡面可能显示异常。")
                    DisclaimerSection(title: "皮肤与版权", text: "内置皮肤不包含任何银行、发卡机构或卡组织的标识。你导入的图片由你自行负责，请确保拥有使用权。")
                    DisclaimerSection(title: "风险自担", text: "是否使用本工具由你自行判断，并自行承担相应风险。在法律允许的最大范围内，开发者不对因使用本工具造成的任何直接或间接损失承担责任。")
                }
                .padding(.horizontal, 32)
            }
            .frame(maxHeight: 320)

            HStack {
                switch mode {
                case .agreement:
                    Button("不同意并退出") { NSApp.terminate(nil) }
                    Spacer()
                    Button("同意并继续", action: onAgree)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                case .reference:
                    Spacer()
                    Button("好的") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .frame(width: 500)
        .interactiveDismissDisabled(mode == .agreement)
    }
}

private struct DisclaimerSection: View {
    let title: String
    let text: String
    var isEmphasized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if isEmphasized { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                Text(title)
            }
            .font(.headline)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 「无法恢复原卡面」的统一说法，免责声明和应用前的确认弹窗共用，保证各处一致。
enum RestoreNotice {
    static let title = "应用后无法通过 WalletBloom 恢复原卡面"
    static let detail = "WalletBloom 不会备份卡片原来的卡面，更换皮肤后无法在 App 内恢复。如需恢复发卡机构的原始卡面，请在 iPhone 钱包中移除这张卡片后重新添加（可能需要发卡机构重新验证）。"
}
