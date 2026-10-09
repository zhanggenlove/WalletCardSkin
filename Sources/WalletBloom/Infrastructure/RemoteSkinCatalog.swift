import Foundation

/// 服务器皮肤清单（manifest）的格式，详见 docs/skin-catalog.md。
struct SkinManifest: Codable {
    var version: Int
    var skins: [Entry]

    struct Entry: Codable {
        /// 必须是 UUID 字符串，作为皮肤的稳定 id（“已应用”“收藏”都依赖它）。
        var id: String
        var name: String
        var subtitle: String?
        var category: String?
        /// 1536×969 的卡面图片地址（HTTPS）。
        var image: URL
    }
}

/// 从服务器拉取皮肤清单；拉取失败时使用上次缓存的清单，保证离线也能看到已有皮肤。
struct RemoteSkinCatalog: SkinCatalog {
    let manifestURL: URL
    let cacheURL: URL

    /// 在 Info.plist 中配置 WBSkinCatalogURL 后启用。
    static var configuredURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "WBSkinCatalogURL") as? String, !value.isEmpty else { return nil }
        return URL(string: value)
    }

    func loadSkins() async throws -> [Skin] {
        let data: Data
        do {
            let (downloaded, response) = try await URLSession.shared.data(from: manifestURL)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw WalletError.unsupported("皮肤清单下载失败（HTTP \(http.statusCode)）")
            }
            _ = try Self.decode(downloaded)
            data = downloaded
            try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: cacheURL, options: .atomic)
        } catch {
            guard let cached = try? Data(contentsOf: cacheURL) else { throw error }
            data = cached
        }
        return try Self.decode(data)
    }

    static func decode(_ data: Data) throws -> [Skin] {
        let manifest = try JSONDecoder().decode(SkinManifest.self, from: data)
        return manifest.skins.compactMap { entry in
            guard let id = UUID(uuidString: entry.id), entry.image.scheme == "https" else { return nil }
            return Skin(id: id, name: entry.name, subtitle: entry.subtitle ?? "", category: entry.category ?? "在线皮肤", artwork: .remoteImage(entry.image))
        }
    }
}

/// 内置占位皮肤 + 服务器皮肤；服务器不可用时只显示内置皮肤。
struct CombinedSkinCatalog: SkinCatalog {
    let remote: RemoteSkinCatalog?

    func loadSkins() async throws -> [Skin] {
        let builtIn = Skin.placeholders
        guard let remote, let online = try? await remote.loadSkins() else { return builtIn }
        let builtInIDs = Set(builtIn.map(\.id))
        return builtIn + online.filter { !builtInIDs.contains($0.id) }
    }
}
