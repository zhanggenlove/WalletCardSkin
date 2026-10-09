import Foundation
import SwiftUI

@MainActor
final class WalletBloomStore: ObservableObject {
    enum Phase: Equatable {
        case launching
        case onboarding
        case scanning
        case noCards
        case failed(String)
        case ready
    }

    @Published private(set) var phase: Phase = .launching
    @Published private(set) var device: Device?
    /// 当前连接的所有设备；多于一台时可在工具栏切换。
    @Published private(set) var devices: [Device] = []
    private var preferredUDID: String?
    @Published private(set) var cards: [WalletCard] = []
    @Published private(set) var skins: [Skin] = []
    @Published private(set) var selectedCardID: WalletCard.ID?
    @Published private(set) var scanProgress: Double = 0
    @Published private(set) var isScanLogConnected = false
    /// 本次扫描已发现的卡片数（不含用户移除过的卡片）。
    @Published private(set) var scanFoundCount = 0
    @Published private(set) var notice: String?
    @Published private var skinSelections: [WalletCard.ID: Skin.ID] = [:]

    // 界面状态放在 store 中，菜单栏命令和界面按钮都可以触发。
    enum InfoSheet: String, Identifiable {
        case disclaimerAgreement
        case disclaimer
        case privacy
        var id: String { rawValue }
    }
    @Published var infoSheet: InfoSheet?
    @Published var isImporterPresented = false
    @Published var renamingCard: WalletCard?
    @Published var isConfirmingApply = false
    @Published var pendingImport: PendingImport?
    @Published var skinSearchText = ""
    @Published var skinFilter: SkinFilter = .all

    enum SkinFilter: Hashable {
        case all
        case favorites
        case category(String)
    }

    struct PendingImport: Identifiable {
        let id = UUID()
        let name: String
        let image: CGImage
    }
    /// 与 WorkspaceView 中的 @AppStorage 共用同一个 key。
    static let suppressRestoreWarningKey = "suppressRestoreWarning"

    let coordinator: DefaultFlashCoordinator
    /// 扫描最长时间；发现卡片后用户可以提前结束。
    let scanDuration: TimeInterval = 30
    private let transport: any WalletTransport
    private let scanner: any WalletCardScanner
    private let skinCatalog: any SkinCatalog
    private let libraryStore: LibraryStore
    private let isToolchainAvailable: Bool
    private var library: LibraryState
    private var scanTask: Task<Void, Never>?
    /// 只负责读取日志的子任务；提前结束扫描时只停止它，后续的设备检查和结果处理照常进行。
    private var scanJob: Task<[String], Error>?
    private var scanFoundHashes = Set<String>()

    init(toolchain: AirliftToolchain = .resolved, skinCatalog: (any SkinCatalog)? = nil, libraryStore: LibraryStore = LibraryStore()) {
        let airlift = AirliftWalletTransport(toolchain: toolchain)
        transport = airlift
        scanner = airlift
        coordinator = DefaultFlashCoordinator(engine: AirliftWalletEngine(toolchain: toolchain))
        isToolchainAvailable = toolchain.isAvailable
        self.skinCatalog = skinCatalog ?? CombinedSkinCatalog(remote: RemoteSkinCatalog.configuredURL.map {
            RemoteSkinCatalog(manifestURL: $0, cacheURL: libraryStore.directory.appendingPathComponent("Catalog/manifest.json"))
        })
        self.libraryStore = libraryStore
        library = libraryStore.load()
    }

    // MARK: - Selection

    var selectedCard: WalletCard? { cards.first { $0.id == selectedCardID } }
    var selectedCardIndex: Int { cards.firstIndex { $0.id == selectedCardID } ?? 0 }
    var selectedSkin: Skin? { selectedCard.flatMap(skin(for:)) }

    /// 卡片当前预览的皮肤：优先用户在本次会话中点选的，其次是已应用的，最后回落到第一个皮肤。
    func skin(for card: WalletCard) -> Skin? {
        let id = skinSelections[card.id] ?? card.currentSkinID
        return skins.first { $0.id == id } ?? skins.first
    }

    func selectCard(_ id: WalletCard.ID) { selectedCardID = id }

    func selectCard(offset: Int) {
        guard !cards.isEmpty else { return }
        let index = (selectedCardIndex + offset + cards.count) % cards.count
        selectedCardID = cards[index].id
    }

    func selectSkin(_ skin: Skin) {
        guard let id = selectedCardID else { return }
        skinSelections[id] = skin.id
    }

    var libraryDirectory: URL { libraryStore.directory }

    var canSwitchDevice: Bool { devices.count > 1 && phase != .scanning && !coordinator.isRunning }

    func selectDevice(_ newDevice: Device) {
        guard canSwitchDevice, devices.contains(newDevice) else { return }
        preferredUDID = newDevice.udid
        device = newDevice
    }

    var compatibility: SystemCompatibility { device.map { SystemCompatibility.check($0.systemVersion) } ?? .unknown }

    var canApply: Bool { phase == .ready && device != nil && !compatibility.isBlocking && selectedCard != nil && selectedSkin != nil && !coordinator.isRunning }
    var canEditCards: Bool { phase == .ready && !coordinator.isRunning }
    var canScan: Bool {
        guard isToolchainAvailable, device != nil, !compatibility.isBlocking, scanTask == nil, !coordinator.isRunning else { return false }
        return phase != .launching && phase != .scanning
    }

    // MARK: - Lifecycle

    func start() async {
        let catalog = (try? await skinCatalog.loadSkins()) ?? []
        skins = catalog + library.importedSkins.map(libraryStore.skin(for:))
        guard isToolchainAvailable else {
            transition(to: .failed(WalletError.toolchainMissing.localizedDescription))
            return
        }
        await refreshDevice()
        if device != nil, await showKnownCards() { return }
        transition(to: .onboarding)
    }

    /// 持续检测设备插拔：断开后回到引导页；在引导页连上且已有卡片时直接进入主界面。
    /// 扫描、同步、或同步结果弹窗还开着时暂停，避免打断用户或和 device_helper 的其他调用抢占设备。
    func monitorConnection() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            guard isToolchainAvailable, coordinator.activeJob == nil else { continue }
            switch phase {
            case .onboarding, .ready, .noCards, .failed: break
            case .launching, .scanning: continue
            }
            await refreshDevice()
            if device == nil {
                if phase != .onboarding { transition(to: .onboarding) }
            } else if phase == .onboarding {
                _ = await showKnownCards()
            }
        }
    }

    func showOnboarding() { transition(to: .onboarding) }

    func retry() async {
        guard isToolchainAvailable else { return }
        await refreshDevice()
        if device == nil { transition(to: .onboarding) } else { startScan() }
    }

    // MARK: - Scanning

    func startScan() {
        guard scanTask == nil, !coordinator.isRunning, !compatibility.isBlocking else { return }
        scanTask = Task {
            await performScan()
            scanTask = nil
        }
    }

    func cancelScan() { scanTask?.cancel() }

    /// 提前结束扫描并保留已发现的卡片。
    func finishScanEarly() {
        guard scanFoundCount > 0 else { return }
        scanJob?.cancel()
    }

    private func performScan() async {
        await refreshDevice()
        guard let device else {
            transition(to: .onboarding)
            return
        }
        notice = nil
        scanProgress = 0
        isScanLogConnected = false
        scanFoundCount = 0
        scanFoundHashes = []
        transition(to: .scanning)

        let started = Date()
        let ticker = Task { [weak self, scanDuration] in
            while !Task.isCancelled {
                self?.scanProgress = min(Date().timeIntervalSince(started) / scanDuration, 1)
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        defer { ticker.cancel() }

        do {
            let job = Task { [scanner, scanDuration] in
                try await scanner.scanCardHashes(on: device, duration: scanDuration) { [weak self] event in
                    Task { @MainActor in self?.handle(event) }
                }
            }
            scanJob = job
            defer { scanJob = nil }
            let hashes = try await withTaskCancellationHandler { try await job.value } onCancel: { job.cancel() }
            guard !Task.isCancelled else { return leaveCancelledScan() }
            // 扫描期间拔掉设备时，日志流会提前结束，结果不可信。
            await refreshDevice()
            guard self.device != nil else { return transition(to: .onboarding) }

            let hidden = Set(library.hiddenCardHashes)
            let known = Set(await knownCards().map(\.cardHash))
            let newHashes = hashes.filter { !hidden.contains($0) && !known.contains($0) }
            if !newHashes.isEmpty {
                library.scannedCardHashes.append(contentsOf: newHashes)
                saveLibrary()
            }

            let merged = await knownCards()
            guard !merged.isEmpty else { return transition(to: .noCards) }
            notice = newHashes.isEmpty ? "未发现新卡片，已显示之前保存的卡片" : "发现 \(newHashes.count) 张新卡片"
            show(merged)
        } catch {
            guard !Task.isCancelled else { return leaveCancelledScan() }
            await refreshDevice()
            transition(to: self.device == nil ? .onboarding : .failed(error.localizedDescription))
        }
    }

    private func handle(_ event: ScanEvent) {
        guard phase == .scanning else { return }
        switch event {
        case .connected:
            isScanLogConnected = true
        case .found(let hash):
            guard !library.hiddenCardHashes.contains(hash), scanFoundHashes.insert(hash).inserted else { return }
            isScanLogConnected = true
            scanFoundCount = scanFoundHashes.count
        }
    }

    private func leaveCancelledScan() {
        transition(to: cards.isEmpty ? .onboarding : .ready)
    }

    // MARK: - Cards

    /// 从列表中移除卡片（例如误识别的卡片），之后的读取和扫描都会忽略它。
    func removeCard(_ card: WalletCard) {
        library.hiddenCardHashes.append(card.cardHash)
        library.scannedCardHashes.removeAll { $0 == card.cardHash }
        saveLibrary()
        cards = labeled(cards.filter { $0.id != card.id })
        skinSelections[card.id] = nil
        if selectedCardID == card.id { selectedCardID = cards.first?.id }
        if cards.isEmpty { transition(to: .noCards) }
    }

    var removedCardCount: Int { library.hiddenCardHashes.count }

    /// 把所有移除过的卡片放回列表（例如误删了真卡）。
    func restoreRemovedCards() async {
        guard !library.hiddenCardHashes.isEmpty else { return }
        for hash in library.hiddenCardHashes where !library.scannedCardHashes.contains(hash) {
            library.scannedCardHashes.append(hash)
        }
        let count = library.hiddenCardHashes.count
        library.hiddenCardHashes = []
        saveLibrary()
        let known = await knownCards()
        if !known.isEmpty { show(known) }
        notice = "已恢复 \(count) 张卡片"
    }

    /// 重命名卡片；名称为空时恢复为默认的「卡片 N」。
    func renameCard(_ card: WalletCard, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        library.cardNames[card.cardHash] = trimmed.isEmpty ? nil : String(trimmed.prefix(20))
        saveLibrary()
        cards = labeled(cards)
    }

    func hasCustomName(_ card: WalletCard) -> Bool { library.cardNames[card.cardHash] != nil }

    // MARK: - Skins

    /// 皮肤库中出现过的分类，按皮肤顺序去重。
    var skinCategories: [String] {
        var seen = Set<String>()
        return skins.map(\.category).filter { seen.insert($0).inserted }
    }

    var visibleSkins: [Skin] {
        let query = skinSearchText.trimmingCharacters(in: .whitespaces)
        return skins.filter { skin in
            switch skinFilter {
            case .all: break
            case .favorites: guard isFavorite(skin) else { return false }
            case .category(let name): guard skin.category == name else { return false }
            }
            guard !query.isEmpty else { return true }
            return [skin.name, skin.subtitle, skin.category].contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    func isFavorite(_ skin: Skin) -> Bool { library.favoriteSkinIDs.contains(skin.id) }

    func toggleFavorite(_ skin: Skin) {
        objectWillChange.send()
        if let index = library.favoriteSkinIDs.firstIndex(of: skin.id) {
            library.favoriteSkinIDs.remove(at: index)
        } else {
            library.favoriteSkinIDs.append(skin.id)
        }
        saveLibrary()
    }

    func isImported(_ skin: Skin) -> Bool {
        library.importedSkins.contains { $0.id == skin.id }
    }

    /// 第一步：读取用户选择的图片，打开裁剪弹窗。
    func beginImport(from url: URL) {
        guard let image = CardArtworkCropper.loadImage(at: url) else {
            notice = "无法读取这张图片，请换一张 PNG、JPEG 或 HEIC 图片"
            return
        }
        pendingImport = PendingImport(name: url.deletingPathExtension().lastPathComponent, image: image)
    }

    /// 第二步：按用户选定的区域裁剪，保存为新的皮肤。
    func finishImport(_ pending: PendingImport, cropRect: CGRect) {
        pendingImport = nil
        let id = UUID()
        do {
            let png = try CardArtworkCropper.renderPNG(pending.image, cropRect: cropRect)
            let fileName = try libraryStore.saveImage(png, id: id)
            let record = LibraryState.ImportedSkin(id: id, name: pending.name, fileName: fileName)
            library.importedSkins.append(record)
            saveLibrary()
            let skin = libraryStore.skin(for: record)
            skins.append(skin)
            selectSkin(skin)
        } catch {
            notice = "导入失败：\(error.localizedDescription)"
        }
    }

    func deleteImportedSkin(_ skin: Skin) {
        guard let index = library.importedSkins.firstIndex(where: { $0.id == skin.id }) else { return }
        libraryStore.removeImage(named: library.importedSkins[index].fileName)
        library.importedSkins.remove(at: index)
        library.appliedSkinIDs = library.appliedSkinIDs.filter { $0.value != skin.id }
        library.favoriteSkinIDs.removeAll { $0 == skin.id }
        saveLibrary()
        skins.removeAll { $0.id == skin.id }
        skinSelections = skinSelections.filter { $0.value != skin.id }
        for index in cards.indices where cards[index].currentSkinID == skin.id {
            cards[index].currentSkinID = nil
        }
    }

    /// 应用前先提醒用户无法恢复原卡面（用户勾选“不再提示”后直接应用）。
    func requestApply() {
        guard canApply else { return }
        if UserDefaults.standard.bool(forKey: Self.suppressRestoreWarningKey) {
            Task { await applySelectedSkin() }
        } else {
            isConfirmingApply = true
        }
    }

    func applySelectedSkin() async {
        guard canApply, let card = selectedCard, let skin = selectedSkin, let device else { return }
        notice = nil
        await coordinator.submit(card: card, skin: skin, on: device)
        guard coordinator.activeJob?.state == .completed else { return }
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index].currentSkinID = skin.id
        }
        library.appliedSkinIDs[card.cardHash] = skin.id
        saveLibrary()
        notice = "已应用「\(skin.name)」· 从后台关闭钱包 App 后重新打开即可看到"
    }

    // MARK: - Private

    private func refreshDevice() async {
        let discovered = (try? await transport.discoverDevices()) ?? []
        if discovered != devices { devices = discovered }
        // 多台设备时沿用用户上次选择的那台；它被拔掉后回落到第一台。
        let current = discovered.first { $0.udid != nil && $0.udid == preferredUDID } ?? discovered.first
        if current != device { device = current }
    }

    /// 本次会话已有的卡片 + AirCard 保存的卡片 + WalletBloom 扫描保存的卡片，去掉用户移除的。
    private func knownCards() async -> [WalletCard] {
        var fromAirCard: [WalletCard] = []
        if let device { fromAirCard = (try? await transport.readWalletCards(from: device)) ?? [] }
        let hidden = Set(library.hiddenCardHashes)
        var result = cards
        var seen = Set(cards.map(\.cardHash))
        for var card in fromAirCard + library.scannedCardHashes.map(WalletCard.detected(hash:))
        where !hidden.contains(card.cardHash) && seen.insert(card.cardHash).inserted {
            card.currentSkinID = library.appliedSkinIDs[card.cardHash]
            result.append(card)
        }
        return result
    }

    private func showKnownCards() async -> Bool {
        let known = await knownCards()
        guard !known.isEmpty else { return false }
        show(known)
        return true
    }

    /// 统一分配显示名称：自定义名称优先，否则按列表顺序命名为「卡片 N」。
    private func labeled(_ list: [WalletCard]) -> [WalletCard] {
        list.enumerated().map { index, card in
            var card = card
            card.title = library.cardNames[card.cardHash] ?? "卡片 \(index + 1)"
            return card
        }
    }

    private func show(_ newCards: [WalletCard]) {
        cards = labeled(newCards)
        if selectedCard == nil { selectedCardID = newCards.first?.id }
        transition(to: .ready)
    }

    private func saveLibrary() {
        do { try libraryStore.save(library) } catch { notice = "本地数据保存失败：\(error.localizedDescription)" }
    }

    private func transition(to newPhase: Phase) {
        // 离开主界面时关闭已结束的同步结果，避免回来时重新弹出。
        if newPhase != .ready { coordinator.dismiss() }
        withAnimation(.smooth(duration: 0.35)) { phase = newPhase }
    }
}
