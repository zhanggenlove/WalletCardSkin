import Foundation

@MainActor
final class DefaultFlashCoordinator: FlashCoordinator, ObservableObject {
    @Published private(set) var activeJob: FlashJob?
    private let engine: any WalletEngine

    init(engine: any WalletEngine) { self.engine = engine }

    var isRunning: Bool { activeJob?.isRunning ?? false }

    func submit(card: WalletCard, skin: Skin, on device: Device) async {
        guard !isRunning else { return }
        activeJob = FlashJob(card: card, skin: skin, state: .preparing, message: "正在准备卡面图片…", progress: 0.04)
        do {
            let file = try await SkinArtworkExporter.export(skin)
            defer { file.cleanUp() }
            update(state: .transferring, message: "正在生成卡面资源…", progress: 0.12)
            try await engine.flash(card: card, imageURL: file.url, on: device) { [weak self] step in
                Task { @MainActor in self?.apply(step) }
            }
            update(state: .completed, message: "「\(skin.name)」已写入「\(card.title)」", progress: 1)
        } catch {
            update(state: .failed(error.localizedDescription), message: error.localizedDescription, progress: activeJob?.progress ?? 0)
        }
    }

    /// 关闭已结束的任务（同步中不可关闭）。
    func dismiss() {
        guard !isRunning else { return }
        activeJob = nil
    }

    private func apply(_ step: FlashProgress) {
        guard isRunning, step.total > 0 else { return }
        let message = step.step <= 1 ? "正在写入卡面到 iPhone…" : "正在刷新钱包缓存…"
        let progress = 0.15 + 0.85 * Double(step.step) / Double(step.total)
        update(state: .transferring, message: "\(message)（\(step.step)/\(step.total)）", progress: progress)
    }

    private func update(state: FlashJob.State, message: String, progress: Double) {
        guard var job = activeJob else { return }
        job.state = state
        job.message = message
        job.progress = max(job.progress, min(progress, 1))
        activeJob = job
    }
}
