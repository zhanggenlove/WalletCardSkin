import Foundation
import Sparkle

/// Sparkle 自动更新。只有在 Info.plist 中配置了 SUFeedURL 和 SUPublicEDKey 后才会启动，
/// 否则 Sparkle 会在每次启动时弹出“更新器启动失败”的错误。配置方法见 docs/roadmap.md。
@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    private let controller: SPUStandardUpdaterController?

    static var isConfigured: Bool {
        let info = Bundle.main.infoDictionary ?? [:]
        let feed = (info["SUFeedURL"] as? String) ?? ""
        let key = (info["SUPublicEDKey"] as? String) ?? ""
        return !feed.isEmpty && !key.isEmpty
    }

    init() {
        guard Self.isConfigured else {
            controller = nil
            return
        }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
