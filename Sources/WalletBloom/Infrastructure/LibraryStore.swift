import Foundation

/// WalletBloom 自己的本地数据，保存在 ~/Library/Application Support/WalletBloom/。
/// 不会写 AirCard 的 ~/.aircard_cards.json。
struct LibraryState: Codable {
    /// WalletBloom 扫描到的卡片 hash。
    var scannedCardHashes: [String] = []
    /// 用户从列表中移除的卡片 hash，读取和扫描结果中都会过滤掉。
    var hiddenCardHashes: [String] = []
    /// 每张卡最近一次成功应用的皮肤（key 为 card hash）。
    var appliedSkinIDs: [String: UUID] = [:]
    /// 用户导入的图片皮肤，图片已复制到 Skins 目录。
    var importedSkins: [ImportedSkin] = []
    /// 用户给卡片起的名称（key 为 card hash）。
    var cardNames: [String: String] = [:]

    struct ImportedSkin: Codable {
        let id: UUID
        var name: String
        var fileName: String
    }

    init() {}

    /// 逐个字段容错解码：旧版本的 library.json 缺少新增字段时，不能因此丢掉整个文件。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scannedCardHashes = try container.decodeIfPresent([String].self, forKey: .scannedCardHashes) ?? []
        hiddenCardHashes = try container.decodeIfPresent([String].self, forKey: .hiddenCardHashes) ?? []
        appliedSkinIDs = try container.decodeIfPresent([String: UUID].self, forKey: .appliedSkinIDs) ?? [:]
        importedSkins = try container.decodeIfPresent([ImportedSkin].self, forKey: .importedSkins) ?? []
        cardNames = try container.decodeIfPresent([String: String].self, forKey: .cardNames) ?? [:]
    }
}

final class LibraryStore {
    let directory: URL
    private var stateURL: URL { directory.appendingPathComponent("library.json") }
    var skinsDirectory: URL { directory.appendingPathComponent("Skins", isDirectory: true) }

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WalletBloom", isDirectory: true)
    }

    func load() -> LibraryState {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(LibraryState.self, from: data) else { return LibraryState() }
        return state
    }

    func save(_ state: LibraryState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: stateURL, options: .atomic)
    }

    /// 保存裁剪好的卡面图片到 App 目录，与原文件无关，原文件被移动或删除后依然可用。
    func saveImage(_ pngData: Data, id: UUID) throws -> String {
        try FileManager.default.createDirectory(at: skinsDirectory, withIntermediateDirectories: true)
        let fileName = "\(id.uuidString).png"
        try pngData.write(to: skinsDirectory.appendingPathComponent(fileName), options: .atomic)
        return fileName
    }

    func removeImage(named fileName: String) {
        try? FileManager.default.removeItem(at: skinsDirectory.appendingPathComponent(fileName))
    }

    func skin(for record: LibraryState.ImportedSkin) -> Skin {
        Skin(id: record.id, name: record.name, subtitle: "自定义图片", artwork: .localImage(skinsDirectory.appendingPathComponent(record.fileName)))
    }
}
