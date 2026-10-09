import SwiftUI
import AppKit

/// 菜单栏：WalletBloom（关于、检查更新）、文件、卡片、帮助。
struct WalletBloomCommands: Commands {
    @ObservedObject var store: WalletBloomStore
    @ObservedObject var coordinator: DefaultFlashCoordinator
    @ObservedObject var updater: AppUpdater
    @AppStorage("acceptedDisclaimerVersion") private var acceptedDisclaimerVersion = 0

    /// 未同意免责声明，或有弹窗（同步进度等）正在显示时，菜单命令一律不可用。
    private var isInteractive: Bool {
        acceptedDisclaimerVersion >= DisclaimerView.version && coordinator.activeJob == nil && store.infoSheet == nil
    }

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("关于 WalletBloom") { showAboutPanel() }
            Button("检查更新…") { updater.checkForUpdates() }
                .disabled(!updater.canCheckForUpdates)
        }

        CommandGroup(replacing: .newItem) {
            Button("导入图片…") { store.isImporterPresented = true }
                .keyboardShortcut("o")
                .disabled(!isInteractive || !store.canEditCards)
            Button("扫描卡片") { store.startScan() }
                .keyboardShortcut("r")
                .disabled(!isInteractive || !store.canScan)
        }

        CommandMenu("卡片") {
            Button("上一张") { store.selectCard(offset: -1) }
                .disabled(!isInteractive || !store.canEditCards || store.cards.count < 2)
            Button("下一张") { store.selectCard(offset: 1) }
                .disabled(!isInteractive || !store.canEditCards || store.cards.count < 2)
            Divider()
            Button("重命名…") { store.renamingCard = store.selectedCard }
                .disabled(!isInteractive || !store.canEditCards || store.selectedCard == nil)
            Button("应用到 iPhone") { store.requestApply() }
                .keyboardShortcut(.return)
                .disabled(!isInteractive || !store.canApply)
            Divider()
            Button("从列表中移除") {
                if let card = store.selectedCard { store.removeCard(card) }
            }
            .disabled(!isInteractive || !store.canEditCards || store.selectedCard == nil)
            Button(store.removedCardCount > 0 ? "恢复已移除的卡片（\(store.removedCardCount)）" : "恢复已移除的卡片") {
                Task { await store.restoreRemovedCards() }
            }
            .disabled(!isInteractive || store.removedCardCount == 0 || coordinator.isRunning || store.phase == .scanning || store.phase == .launching)
        }

        CommandGroup(replacing: .help) {
            Button("隐私与安全") { store.infoSheet = .privacy }
                .disabled(!isInteractive)
            Button("免责声明") { store.infoSheet = .disclaimer }
                .disabled(!isInteractive)
            Divider()
            Button("联系技术支持…") {
                if let url = SupportContact.mailURL(subject: "WalletBloom 反馈", body: "") { NSWorkspace.shared.open(url) }
            }
        }
    }

    private func showAboutPanel() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let credits = NSAttributedString(
            string: "为 iPhone 钱包中的卡片更换皮肤。\n所有操作通过数据线在本机完成，不上传任何数据。",
            attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: paragraph]
        )
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate()
    }
}
