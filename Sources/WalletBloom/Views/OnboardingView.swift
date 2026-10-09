import SwiftUI

/// 未连接设备（或尚未扫描过卡片）时的引导页。
struct OnboardingView: View {
    @ObservedObject var store: WalletBloomStore
    let onShowPrivacy: () -> Void

    private var isConnected: Bool { store.device != nil }

    var body: some View {
        HStack(spacing: 56) {
            ConnectIllustration(isConnected: isConnected)

            VStack(alignment: .leading, spacing: 0) {
                Text("连接你的 iPhone")
                    .font(.title.weight(.bold))
                Text("按以下步骤操作，即可扫描钱包中的卡片")
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 18) {
                    OnboardingStep(number: 1, systemImage: "cable.connector", title: "用数据线连接 Mac 与 iPhone", detail: "推荐使用原装数据线，避免使用仅支持充电的线材", isDone: isConnected)
                    OnboardingStep(number: 2, systemImage: "lock.shield", title: "在 iPhone 上点按「信任此电脑」", detail: "解锁 iPhone 并输入锁屏密码以完成授权", isDone: isConnected)
                    OnboardingStep(number: 3, systemImage: "wallet.pass", title: "打开 iPhone 上的钱包 App", detail: "或连按两下侧边按钮唤起钱包", isDone: false)
                    OnboardingStep(number: 4, systemImage: "sparkle.magnifyingglass", title: "点击下方「开始扫描卡片」", detail: "最长 \(Int(store.scanDuration)) 秒，发现卡片后可以提前完成", isDone: false)
                }
                .padding(.top, 26)

                Button {
                    store.startScan()
                } label: {
                    Text("开始扫描卡片").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!isConnected)
                .padding(.top, 28)

                connectionHint
                    .font(.callout)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
            .frame(maxWidth: 380)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill").foregroundStyle(.green)
                Text("只更换卡面外观：不读取支付信息、不上传任何数据、不影响刷卡。")
                Button("了解更多", action: onShowPrivacy)
                    .buttonStyle(.link)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private var connectionHint: some View {
        if let device = store.device {
            Label("已连接 \(device.name)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("正在等待 iPhone 连接…")
            }
            .foregroundStyle(.secondary)
        }
    }
}

private struct OnboardingStep: View {
    let number: Int
    let systemImage: String
    let title: String
    let detail: String
    let isDone: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .overlay {
                            Text("\(number)")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 26, height: 26)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDone)

            VStack(alignment: .leading, spacing: 3) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .labelStyle(StepLabelStyle())
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 3)
        }
    }
}

private struct StepLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.foregroundStyle(.secondary).font(.callout)
            configuration.title
        }
    }
}

/// iPhone → Mac 的连接示意，连接成功后箭头变为对勾。
private struct ConnectIllustration: View {
    let isConnected: Bool

    var body: some View {
        ZStack {
            PulseRings(color: isConnected ? .green : .accentColor)
                .frame(width: 130, height: 130)

            VStack(spacing: 14) {
                Image(systemName: "iphone")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(.tint)
                Image(systemName: isConnected ? "checkmark.circle.fill" : "arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isConnected ? Color.green : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                AppGlyph(size: 38)
            }
            .frame(width: 136, height: 206)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
        }
        .frame(width: 190, height: 250)
    }
}
