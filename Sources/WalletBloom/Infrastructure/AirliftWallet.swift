import Foundation

struct AirliftToolchain: Sendable {
    let deviceHelperURL: URL
    let backendURL: URL
    /// App 内嵌的 Python 解释器；为 nil 时回退到系统 python3。
    let pythonURL: URL?

    var isAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: deviceHelperURL.path) &&
        FileManager.default.isReadableFile(atPath: backendURL.path)
    }

    /// 刷入用的解释器：优先 App 内嵌的 Python，其次系统 python3（可能缺失）。
    var pythonInvocation: (executable: URL, leadingArguments: [String]) {
        if let pythonURL, FileManager.default.isExecutableFile(atPath: pythonURL.path) {
            return (pythonURL, [])
        }
        return (URL(fileURLWithPath: "/usr/bin/env"), ["python3"])
    }

    static func fromRepository(_ root: URL) -> AirliftToolchain {
        let build = root.appendingPathComponent("build")
        return AirliftToolchain(
            deviceHelperURL: build.appendingPathComponent("device_helper"),
            backendURL: root.appendingPathComponent("aircard_backend.py"),
            pythonURL: bundledPythonURL
        )
    }

    static var fromApplicationBundle: AirliftToolchain {
        let resources = Bundle.main.resourceURL ?? URL(fileURLWithPath: "")
        let bin = resources.appendingPathComponent("bin")
        return AirliftToolchain(
            deviceHelperURL: bin.appendingPathComponent("device_helper"),
            backendURL: resources.appendingPathComponent("aircard_backend.py"),
            pythonURL: bundledPythonURL
        )
    }

    /// Contents/Resources/python-<arch>/bin/python3；Apple Silicon 用 arm64，Intel 用 x86_64。
    /// 放在 Resources 而非 Frameworks：Python 目录里的 include、tcl 等子目录会让 codesign 误当成 bundle。
    static var bundledPythonURL: URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let python = resources
            .appendingPathComponent("python-\(isAppleSilicon ? "arm64" : "x86_64")")
            .appendingPathComponent("bin/python3")
        return FileManager.default.isExecutableFile(atPath: python.path) ? python : nil
    }

    private static let isAppleSilicon: Bool = {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
    }()

    /// 优先使用 App 包内的工具链；开发时（swift run / Xcode）可通过 AIR_CARD_ROOT 指向 AirCard 仓库。
    static var resolved: AirliftToolchain {
        let bundled = fromApplicationBundle
        if bundled.isAvailable { return bundled }
        if let root = ProcessInfo.processInfo.environment["AIR_CARD_ROOT"] {
            let repository = fromRepository(URL(fileURLWithPath: root))
            if repository.isAvailable { return repository }
        }
        return bundled
    }
}

struct AirliftProcessResult: Sendable {
    let exitCode: Int32
    let output: [String]

    var jsonObjects: [[String: Any]] { output.compactMap(Self.jsonObject(from:)) }
    var lastJSONObject: [String: Any]? { output.reversed().lazy.compactMap(Self.jsonObject(from:)).first }

    static func jsonObject(from line: String) -> [String: Any]? {
        guard line.first == "{", let data = line.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

struct AirliftProcess: Sendable {
    enum Limit {
        /// 超过时限视为失败（刷入、设备列表）。
        case timeout(TimeInterval)
        /// 运行满指定时长后正常结束（日志扫描）。
        case duration(TimeInterval)
    }

    /// 运行子进程并持续读取输出：边读边回调每一行，避免输出超过管道缓冲时子进程阻塞。
    /// 所在 Task 被取消时会终止子进程。
    func run(_ executable: URL, arguments: [String], limit: Limit, onLine: (@Sendable (String) -> Void)? = nil) async throws -> AirliftProcessResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(["PYTHONDONTWRITEBYTECODE": "1", "PYTHONUNBUFFERED": "1"]) { _, new in new }
        process.standardOutput = pipe
        process.standardError = pipe

        let collector = LineCollector(onLine: onLine)
        let endOfFile = DispatchSemaphore(value: 0)
        let didTimeOut = LockedFlag()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                endOfFile.signal()
            } else {
                collector.append(data)
            }
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AirliftProcessResult, Error>) in
                process.terminationHandler = { process in
                    // 等待管道读完；若有孙进程仍占用管道，最多再等 2 秒。
                    _ = endOfFile.wait(timeout: .now() + 2)
                    pipe.fileHandleForReading.readabilityHandler = nil
                    let lines = collector.finish()
                    if didTimeOut.isSet {
                        continuation.resume(throwing: WalletError.unsupported("AirCard 操作超时，请检查数据线连接后重试"))
                    } else {
                        continuation.resume(returning: AirliftProcessResult(exitCode: process.terminationStatus, output: lines))
                    }
                }
                do {
                    try process.run()
                } catch {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                    return
                }
                switch limit {
                case .timeout(let seconds):
                    DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                        guard process.isRunning else { return }
                        didTimeOut.set()
                        process.terminate()
                    }
                case .duration(let seconds):
                    DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                        if process.isRunning { process.terminate() }
                    }
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }
}

/// 线程安全地拼接管道输出并按行切分。
private final class LineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var lines: [String] = []
    private let onLine: (@Sendable (String) -> Void)?

    init(onLine: (@Sendable (String) -> Void)?) { self.onLine = onLine }

    func append(_ data: Data) {
        lock.lock()
        buffer.append(data)
        var completed: [String] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            completed.append(String(decoding: buffer[buffer.startIndex..<newline], as: UTF8.self))
            buffer.removeSubrange(buffer.startIndex...newline)
        }
        lines.append(contentsOf: completed)
        lock.unlock()
        completed.forEach { onLine?($0) }
    }

    func finish() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        if !buffer.isEmpty {
            let rest = String(decoding: buffer, as: UTF8.self)
            buffer.removeAll()
            lines.append(rest)
            onLine?(rest)
        }
        return lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
    func set() { lock.lock(); value = true; lock.unlock() }
}

struct AirliftWalletTransport: WalletTransport, WalletCardScanner {
    let toolchain: AirliftToolchain
    let process = AirliftProcess()
    private let storeURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".aircard_cards.json")

    func discoverDevices() async throws -> [Device] {
        guard toolchain.isAvailable else { throw WalletError.toolchainMissing }
        let result = try await process.run(toolchain.deviceHelperURL, arguments: ["list"], limit: .timeout(30))
        guard result.exitCode == 0 else { throw WalletError.deviceUnavailable }
        let line = result.output.reversed().first(where: { $0.first == "[" }) ?? "[]"
        let records = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [[String: Any]] ?? []
        return records.compactMap { record in
            guard let udid = record["udid"] as? String, !udid.isEmpty else { return nil }
            let product = record["product"] as? String ?? "iPhone"
            return Device(id: UUID(deterministicFrom: udid), udid: udid, name: record["name"] as? String ?? "iPhone", model: product, systemVersion: record["version"] as? String ?? "Unknown", connection: .usb)
        }
    }

    /// 只读取 AirCard CLI 保存的卡片（~/.aircard_cards.json），WalletBloom 不会写这个文件。
    func readWalletCards(from device: Device) async throws -> [WalletCard] {
        guard let data = try? Data(contentsOf: storeURL),
              let hashes = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return hashes.map(WalletCard.detected(hash:))
    }

    func scanCardHashes(on device: Device, duration: TimeInterval, onEvent: @escaping @Sendable (ScanEvent) -> Void) async throws -> [String] {
        guard let udid = device.udid else { throw WalletError.deviceUnavailable }
        guard toolchain.isAvailable else { throw WalletError.toolchainMissing }
        let result = try await process.run(toolchain.deviceHelperURL, arguments: ["syslog", udid], limit: .duration(duration)) { line in
            if line.contains(CardHashExtractor.connectedMarker) { onEvent(.connected) }
            CardHashExtractor.extract(from: [line]).forEach { onEvent(.found($0)) }
        }
        return CardHashExtractor.extract(from: result.output)
    }

    func write(_ assets: [WalletAsset], to device: Device) async throws {
        throw WalletError.unsupported("Airlift 刷入需要 card hash；请通过 AirliftWalletEngine 执行")
    }

    func refreshWallet(on device: Device) async throws {
        throw WalletError.unsupported("缓存清理由 AirCard backend 在刷入流程中完成")
    }
}

/// 从设备日志中提取 Wallet 卡片 hash。
enum CardHashExtractor {
    /// device_helper 连上统一日志流时输出的提示（见 AirCard README）。
    static let connectedMarker = "Connected to the unified device log stream"

    /// 路径形式（…/Passes/Cards/<hash>.pkpass）足够明确，任何进程的日志都采信。
    private static let pathPatterns = [
        #"/(?:Cards|Passes/Cards)/([-A-Za-z0-9_+=]{20,44})(?:\.pkpass|\.cache|\.pkcache|/|\s|\"|\'|\)|,|$)"#,
        #"/([-A-Za-z0-9_+=]{20,44})\.(?:pkpass|cache|pkcache)"#
    ].compactMap { try? NSRegularExpression(pattern: $0) }

    /// 裸 hash（27 个字符 + "="）和 apsd、cloudd、identityservicesd 等进程输出的 base64 token 格式完全一样，
    /// 只在 Wallet 相关进程的日志行中采信，否则会把推送/同步 token 误认成卡片。
    private static let bareHashPattern = try? NSRegularExpression(pattern: #"(?<![A-Za-z0-9+/_-])([A-Za-z0-9+/_-]{27}=)(?![A-Za-z0-9+/_-])"#)
    private static let walletSourceKeywords = ["pass", "wallet", "nfc", "seserviced", "stockholm"]

    static func extract(from lines: [String]) -> [String] {
        var found = Set<String>()
        for line in lines {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            var patterns = pathPatterns
            if let bareHashPattern, isWalletSource(line) { patterns.append(bareHashPattern) }
            for regex in patterns {
                for match in regex.matches(in: line, range: range) {
                    guard match.numberOfRanges > 1, let hashRange = Range(match.range(at: 1), in: line) else { continue }
                    let hash = String(line[hashRange])
                    if hash.count >= 20 { found.insert(hash) }
                }
            }
        }
        return found.sorted()
    }

    /// 日志行格式为 `进程名(库名): 消息`，根据冒号前的来源判断是否来自 Wallet 相关进程。
    private static func isWalletSource(_ line: String) -> Bool {
        guard let colon = line.firstIndex(of: ":") else { return false }
        let source = line[..<colon].lowercased()
        guard !source.contains(" ") else { return false }
        return walletSourceKeywords.contains { source.contains($0) }
    }
}

struct AirliftWalletEngine: WalletEngine {
    let toolchain: AirliftToolchain
    let process = AirliftProcess()

    func flash(card: WalletCard, imageURL: URL, on device: Device, progress: @escaping @Sendable (FlashProgress) -> Void) async throws {
        guard toolchain.isAvailable else { throw WalletError.toolchainMissing }
        let python = toolchain.pythonInvocation
        let arguments = python.leadingArguments + [toolchain.backendURL.path, "flash", device.udid ?? device.id.uuidString, card.cardHash, imageURL.path]
        let result = try await process.run(python.executable, arguments: arguments, limit: .timeout(180)) { line in
            guard let event = AirliftProcessResult.jsonObject(from: line),
                  event["type"] as? String == "progress",
                  let step = event["step"] as? Int, let total = event["total"] as? Int else { return }
            progress(FlashProgress(step: step, total: total))
        }

        // backend 成功时最后一行是 {"type": "success"}，失败时是 {"type": "error"} 或 {"ok": false}。
        let events = result.jsonObjects
        let succeeded = result.exitCode == 0 && events.contains { $0["type"] as? String == "success" || $0["ok"] as? Bool == true }
        guard succeeded else {
            // 取第一条错误：backend 会先输出具体原因，最后再补一条笼统的 “Failed to update …”。
            let failure = events.first { $0["type"] as? String == "error" || $0["ok"] as? Bool == false }
            guard let message = failure?["message"] as? String ?? failure?["error"] as? String else {
                throw WalletError.unsupported("写入失败（退出码 \(result.exitCode)），请重新连接 iPhone 后再试")
            }
            throw WalletError.unsupported(BackendMessage.localized(message))
        }
    }
}

/// 把 AirCard backend 的英文报错转成用户能看懂的中文，并给出下一步建议。
enum BackendMessage {
    private static let rules: [(prefix: String, text: String)] = [
        ("Image file not found", "找不到要写入的卡面图片，请重新选择皮肤后再试"),
        ("Failed to prepare card artwork", "卡面图片处理失败，请换一张图片后再试"),
        ("Could not clear Wallet cache", "无法刷新钱包缓存，新卡面可能没有生效。请解锁 iPhone、重新连接后再试"),
        ("Failed to update", "写入卡面失败。请确认 iPhone 已解锁并保持数据线连接，然后重试")
    ]

    static func localized(_ message: String) -> String {
        rules.first { message.hasPrefix($0.prefix) }?.text ?? "写入失败：\(message)"
    }
}
