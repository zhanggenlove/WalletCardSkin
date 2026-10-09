import Foundation

struct WalletAsset {
    let name: String
    let data: Data
    let uti: String
}

protocol ImageProcessor {
    func process(imageData: Data, targetSize: CGSize) throws -> Data
}

protocol WalletAssetBuilder {
    func makeAssets(for card: WalletCard, skin: Skin) throws -> [WalletAsset]
}

protocol WalletTransport {
    func discoverDevices() async throws -> [Device]
    func readWalletCards(from device: Device) async throws -> [WalletCard]
    func write(_ assets: [WalletAsset], to device: Device) async throws
    func refreshWallet(on device: Device) async throws
}

protocol WalletCardScanner {
    /// 扫描设备日志中的卡片 hash；`onEvent` 在扫描过程中实时回调（可能来自后台线程）。
    func scanCardHashes(on device: Device, duration: TimeInterval, onEvent: @escaping @Sendable (ScanEvent) -> Void) async throws -> [String]
}

enum ScanEvent: Sendable {
    /// 已连接到设备的统一日志流。
    case connected
    /// 发现一个卡片 hash（同一个 hash 可能多次回调）。
    case found(String)
}

protocol WalletEngine {
    func flash(card: WalletCard, imageURL: URL, on device: Device, progress: @escaping @Sendable (FlashProgress) -> Void) async throws
}


@MainActor
protocol FlashCoordinator {
    func submit(card: WalletCard, skin: Skin, on device: Device) async
}

enum WalletError: LocalizedError {
    case unsupported(String)
    case invalidAsset
    case deviceUnavailable
    case toolchainMissing

    var errorDescription: String? {
        switch self {
        case .unsupported(let detail): return detail
        case .invalidAsset: return "皮肤资源无效"
        case .deviceUnavailable: return "未找到可用的 iPhone"
        case .toolchainMissing: return "未找到 AirCard 工具链（device_helper / aircard_backend.py）。请使用 scripts/package_app.sh 打包后的 App，或设置 AIR_CARD_ROOT 环境变量。"
        }
    }
}

// TODO: 占位信息，上线前替换为真实的技术支持渠道。
enum SupportContact {
    static let email = "support@example.com"

    static func mailURL(subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        return components.url
    }
}
