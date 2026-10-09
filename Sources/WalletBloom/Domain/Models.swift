import Foundation

struct Device: Identifiable, Hashable {
    let id: UUID
    var udid: String?
    var name: String
    var model: String
    var systemVersion: String
    var connection: Connection

    enum Connection: String, Codable {
        case disconnected
        case usb
        case wifi
    }
}

struct WalletCard: Identifiable, Hashable {
    let id: UUID
    var cardHash: String
    /// 显示名称：用户自定义的名称，或按顺序生成的「卡片 N」，由 store 统一分配。
    var title: String
    var kind: Kind
    var currentSkinID: UUID?

    enum Kind: String, CaseIterable {
        case payment = "银行卡"
        case transit = "交通卡"
        case pass = "会员卡"

        var symbolName: String {
            switch self {
            case .payment: return "creditcard.fill"
            case .transit: return "tram.fill"
            case .pass: return "ticket.fill"
            }
        }
    }

    /// Wallet 卡面图片的像素尺寸，刷入前的图片都会被渲染或裁切到这个尺寸。
    static let artworkPixelSize = CGSize(width: 1536, height: 969)
    static let artworkAspectRatio = artworkPixelSize.width / artworkPixelSize.height

    /// 由 AirCard 扫描到的 card hash 构造卡片；同一个 hash 始终得到同一个 id。
    static func detected(hash: String) -> WalletCard {
        WalletCard(id: UUID(deterministicFrom: hash), cardHash: hash, title: "卡片", kind: .payment, currentSkinID: nil)
    }
}

struct Skin: Identifiable, Hashable {
    let id: UUID
    var name: String
    var subtitle: String
    var artwork: Artwork

    enum Artwork: Hashable {
        /// 内置渐变占位皮肤，刷入前渲染成 PNG。
        case gradient([String])
        /// 用户导入的本地图片。
        case localImage(URL)
        /// 服务器下发的皮肤图片，刷入前下载到临时目录。
        case remoteImage(URL)
    }

    // TODO: 皮肤后续改为从服务器拉取（实现一个 RemoteSkinCatalog），这里的渐变仅作占位。
    static let placeholders = [
        Skin(id: UUID(uuidString: "8A7D5C30-19E4-4EC8-9C5E-000000000101")!, name: "Sakura", subtitle: "柔和樱花", artwork: .gradient(["F6B7C8", "D9779B"])),
        Skin(id: UUID(uuidString: "8A7D5C30-19E4-4EC8-9C5E-000000000102")!, name: "Tokyo Night", subtitle: "城市霓虹", artwork: .gradient(["171B35", "5B4AA8"])),
        Skin(id: UUID(uuidString: "8A7D5C30-19E4-4EC8-9C5E-000000000103")!, name: "Minimal", subtitle: "纯净留白", artwork: .gradient(["F1EEE8", "BEB7AC"])),
        Skin(id: UUID(uuidString: "8A7D5C30-19E4-4EC8-9C5E-000000000104")!, name: "Aurora", subtitle: "极光渐变", artwork: .gradient(["00C6A7", "1E4AE9"])),
        Skin(id: UUID(uuidString: "8A7D5C30-19E4-4EC8-9C5E-000000000105")!, name: "Sunset", subtitle: "黄昏落日", artwork: .gradient(["FF9966", "FF5E62"])),
        Skin(id: UUID(uuidString: "8A7D5C30-19E4-4EC8-9C5E-000000000106")!, name: "Ocean", subtitle: "深海蓝调", artwork: .gradient(["2E3192", "1BFFFF"])),
        Skin(id: UUID(uuidString: "8A7D5C30-19E4-4EC8-9C5E-000000000107")!, name: "Grape", subtitle: "葡萄紫韵", artwork: .gradient(["8E2DE2", "4A00E0"])),
        Skin(id: UUID(uuidString: "8A7D5C30-19E4-4EC8-9C5E-000000000108")!, name: "Forest", subtitle: "森林绿意", artwork: .gradient(["134E5E", "71B280"]))
    ]
}

struct FlashJob: Identifiable {
    let id = UUID()
    let card: WalletCard
    let skin: Skin
    var state: State
    var message: String
    /// 0...1 的整体同步进度。
    var progress: Double

    enum State: Equatable {
        case preparing
        case transferring
        case completed
        case failed(String)
    }

    var isRunning: Bool { state == .preparing || state == .transferring }
}

/// AirCard backend 刷入过程中上报的步骤（写入卡面、清理两个缓存目录、收尾）。
struct FlashProgress: Sendable {
    let step: Int
    let total: Int
}

extension UUID {
    /// 把任意字符串折叠成稳定的 UUID，用于让同一设备/卡片在多次读取之间保持相同 id。
    init(deterministicFrom value: String) {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, byte) in value.utf8.enumerated() { bytes[index % 16] ^= byte }
        self.init(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
