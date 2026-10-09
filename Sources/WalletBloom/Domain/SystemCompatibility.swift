import Foundation

/// iPhone 系统版本兼容性。范围来自 AirCard：支持 iOS 18 及以上，已在 iOS 27 正式版上测试。
/// AirCard 更新支持范围后同步修改这里的两个常量。
enum SystemCompatibility: Equatable {
    case supported
    /// 高于已测试版本，允许使用但提示风险。
    case untested(String)
    /// 低于最低版本，不能扫描和应用。
    case unsupported(String)
    /// 版本号无法识别时不阻止使用。
    case unknown

    static let minimumMajorVersion = 18
    static let testedMajorVersion = 27

    static func check(_ systemVersion: String) -> SystemCompatibility {
        let digits = systemVersion.drop { !$0.isNumber }
        guard let major = Int(digits.prefix { $0.isNumber }) else { return .unknown }
        let version = String(digits.prefix { $0.isNumber || $0 == "." })
        if major < minimumMajorVersion { return .unsupported(version) }
        if major > testedMajorVersion { return .untested(version) }
        return .supported
    }

    var isBlocking: Bool {
        if case .unsupported = self { return true }
        return false
    }

    /// 给用户看的说明；支持的版本返回 nil。
    var message: String? {
        switch self {
        case .supported, .unknown:
            return nil
        case .untested(let version):
            return "iOS \(version) 尚未经过测试，可能无法正常使用"
        case .unsupported(let version):
            return "iOS \(version) 不受支持，需要 iOS \(Self.minimumMajorVersion) 或更高版本"
        }
    }
}
