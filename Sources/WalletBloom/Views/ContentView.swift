import SwiftUI

struct ContentView: View {
    @ObservedObject var store: WalletBloomStore
    @AppStorage("acceptedDisclaimerVersion") private var acceptedDisclaimerVersion = 0

    var body: some View {
        ZStack {
            Group {
                screen
            }
            .transition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("WalletBloom")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 8) {
                    AppGlyph(size: 22)
                    Text("WalletBloom").font(.headline)
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { store.infoSheet = .privacy } label: {
                    Label("隐私与安全", systemImage: "hand.raised")
                }
                .help("隐私与安全：WalletBloom 不会上传或读取你的支付信息")
                ConnectionBadge(store: store)
            }
        }
        .sheet(item: presentedSheet) { sheet in
            switch sheet {
            case .disclaimerAgreement:
                DisclaimerView(mode: .agreement) { acceptedDisclaimerVersion = DisclaimerView.version }
            case .disclaimer:
                DisclaimerView(mode: .reference)
            case .privacy:
                PrivacyView(libraryDirectory: store.libraryDirectory)
            }
        }
        .task {
            await store.start()
            await store.monitorConnection()
        }
    }

    /// 未同意当前版本的免责声明时，优先展示同意页，其余弹窗排在它之后。
    private var presentedSheet: Binding<WalletBloomStore.InfoSheet?> {
        Binding(
            get: { acceptedDisclaimerVersion < DisclaimerView.version ? .disclaimerAgreement : store.infoSheet },
            set: { store.infoSheet = $0 == .disclaimerAgreement ? nil : $0 }
        )
    }

    @ViewBuilder
    private var screen: some View {
        switch store.phase {
        case .launching:
            ProgressView()
        case .onboarding:
            OnboardingView(store: store) { store.infoSheet = .privacy }
        case .scanning:
            ScanningView(store: store)
        case .noCards:
            NoCardsView(store: store)
        case .failed(let message):
            ScanFailedView(store: store, message: message)
        case .ready:
            WorkspaceView(store: store, coordinator: store.coordinator)
        }
    }
}

private struct ConnectionBadge: View {
    @ObservedObject var store: WalletBloomStore

    private var device: Device? { store.device }

    var body: some View {
        if store.devices.count > 1 {
            Menu {
                Picker("选择 iPhone", selection: Binding(get: { store.device }, set: { if let selected = $0 { store.selectDevice(selected) } })) {
                    ForEach(store.devices) { device in
                        Text("\(device.name)（iOS \(device.systemVersion)）").tag(Optional(device))
                    }
                }
                .pickerStyle(.inline)
            } label: {
                badge
            }
            .disabled(!store.canSwitchDevice)
            .help("已连接 \(store.devices.count) 台 iPhone，点按切换")
        } else {
            badge
                .help(device.map { "\($0.model) · iOS \($0.systemVersion)" + (SystemCompatibility.check($0.systemVersion).message.map { "\n\($0)" } ?? "") } ?? "请使用数据线连接 iPhone")
        }
    }

    private var badge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(device == nil ? Color.secondary.opacity(0.6) : Color.green)
                .frame(width: 7, height: 7)
            Text(device?.name ?? "未连接设备")
                .foregroundStyle(device == nil ? .secondary : .primary)
        }
        .font(.callout)
        .padding(.horizontal, 8)
    }
}
