import SwiftUI

@main
struct WalletBloomApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var store = WalletBloomStore()
    @StateObject private var updater = AppUpdater()

    var body: some Scene {
        // 单窗口应用：所有状态都在同一个 store 中，不支持多开窗口。
        Window("WalletBloom", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 720)
                .onAppear { appDelegate.coordinator = store.coordinator }
        }
        .defaultSize(width: 1180, height: 820)
        // 标题和图标由工具栏自定义项显示（见 ContentView）。
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            WalletBloomCommands(store: store, coordinator: store.coordinator, updater: updater)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var coordinator: DefaultFlashCoordinator?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// 同步过程中退出会中断写入，先征得用户确认。
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard coordinator?.isRunning == true else { return .terminateNow }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "正在同步皮肤到 iPhone"
        alert.informativeText = "现在退出会中断写入，卡面可能显示异常。建议等待同步完成后再退出。"
        alert.addButton(withTitle: "继续等待")
        alert.addButton(withTitle: "仍要退出")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}
