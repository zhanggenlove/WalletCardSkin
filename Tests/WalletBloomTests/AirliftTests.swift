import XCTest
import AppKit
@testable import WalletBloom

final class CardHashExtractorTests: XCTestCase {
    private let cardHash = "e6c42Q8tXIOOufsm3Vw4hofx5sI="

    func testPathMatchesAreAcceptedFromAnyProcess() {
        let lines = ["SpringBoard(FrontBoard): opened /var/mobile/Library/Passes/Cards/\(cardHash).pkpass"]
        XCTAssertEqual(CardHashExtractor.extract(from: lines), [cardHash])
    }

    func testBareTokensFromNonWalletProcessesAreIgnored() {
        let lines = [
            "apsd(ApplePushService): topic hash 2z3lvOAAAWzapTbLBMM7yQDcfeo= enabled",
            "cloudd(CloudKit): record 7xkvuR/kIaEu49+1gDRQNs+7i7Y= fetched",
            "identityservicesd: token XMYQqIjn5XX9Uj8SM+qCorcYJxA="
        ]
        XCTAssertEqual(CardHashExtractor.extract(from: lines), [])
    }

    func testBareHashesFromWalletProcessesAreAccepted() {
        let lines = ["passd(PassKitCore): updating pass \(cardHash) in database"]
        XCTAssertEqual(CardHashExtractor.extract(from: lines), [cardHash])
    }

    func testMessageTextCannotSpoofTheSource() {
        // “pass” 出现在消息正文里，而不是来源字段里。
        let lines = ["apsd: note: pass token 2z3lvOAAAWzapTbLBMM7yQDcfeo="]
        XCTAssertEqual(CardHashExtractor.extract(from: lines), [])
    }
}

final class AirliftProcessTests: XCTestCase {
    private let shell = URL(fileURLWithPath: "/bin/sh")

    func testLargeOutputDoesNotDeadlock() async throws {
        // 约 400 KB 输出，远超管道缓冲；旧实现会一直阻塞到超时。
        let result = try await AirliftProcess().run(shell, arguments: ["-c", "i=0; while [ $i -lt 8000 ]; do echo line-$i-................................................; i=$((i+1)); done"], limit: .timeout(10))
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.output.count, 8000)
        XCTAssertEqual(result.output.last?.hasPrefix("line-7999"), true)
    }

    func testDurationStopsLongRunningProcessWithoutError() async throws {
        let started = Date()
        let result = try await AirliftProcess().run(shell, arguments: ["-c", "echo ready; sleep 30"], limit: .duration(0.5))
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
        XCTAssertEqual(result.output, ["ready"])
    }

    func testTimeoutThrows() async {
        do {
            _ = try await AirliftProcess().run(shell, arguments: ["-c", "sleep 30"], limit: .timeout(0.5))
            XCTFail("expected timeout")
        } catch {}
    }

    func testCancellationTerminatesProcess() async throws {
        let started = Date()
        let task = Task { try await AirliftProcess().run(shell, arguments: ["-c", "sleep 30"], limit: .duration(30)) }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        _ = try await task.value
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testLinesAreStreamedAsTheyArrive() async throws {
        let received = LockedLines()
        _ = try await AirliftProcess().run(shell, arguments: ["-c", "echo one; echo two; printf three"], limit: .timeout(5)) { received.append($0) }
        XCTAssertEqual(received.values, ["one", "two", "three"])
    }
}

final class AirliftWalletEngineTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("walletbloom-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// 生成一个模拟 aircard_backend.py 的脚本，按给定内容输出并以给定退出码结束。
    private func engine(printing lines: [String], exitCode: Int32 = 0) throws -> AirliftWalletEngine {
        let backend = directory.appendingPathComponent("aircard_backend.py")
        let body = lines.map { "print(\(String(reflecting: $0)))" }.joined(separator: "\n")
        try "import sys\n\(body)\nsys.exit(\(exitCode))\n".write(to: backend, atomically: true, encoding: .utf8)
        return AirliftWalletEngine(toolchain: AirliftToolchain(deviceHelperURL: URL(fileURLWithPath: "/usr/bin/true"), backendURL: backend))
    }

    private let card = WalletCard.detected(hash: "e6c42Q8tXIOOufsm3Vw4hofx5sI=")
    private let device = Device(id: UUID(), udid: "test-udid", name: "iPhone", model: "iPhone14,4", systemVersion: "27.0", connection: .usb)

    func testSuccessEventIsTreatedAsSuccess() async throws {
        // 真实 backend 成功时的输出：只有 type=success，没有 ok 字段。旧实现把它当成失败。
        let engine = try engine(printing: [
            #"{"type": "progress", "card": "x", "step": 1, "total": 4, "message": "Writing 5 artwork files (fast batch)..."}"#,
            #"{"type": "progress", "card": "x", "step": 2, "total": 4, "message": "Invalidating cache (.cache)..."}"#,
            #"{"type": "progress", "card": "x", "step": 3, "total": 4, "message": "Invalidating cache (.pkcache)..."}"#,
            #"{"type": "success", "card": "x", "step": 4, "total": 4, "message": "Successfully updated e6c42Q8tXIOO..."}"#
        ])
        let steps = LockedLines()
        try await engine.flash(card: card, imageURL: directory, on: device) { steps.append("\($0.step)/\($0.total)") }
        XCTAssertEqual(steps.values, ["1/4", "2/4", "3/4"])
    }

    func testErrorEventThrowsItsMessage() async throws {
        let engine = try engine(printing: [
            #"{"type": "progress", "card": "x", "step": 1, "total": 4, "message": "Writing"}"#,
            #"{"type": "error", "card": "x", "step": 2, "total": 4, "message": "Could not clear Wallet cache (.cache)"}"#
        ], exitCode: 1)
        do {
            try await engine.flash(card: card, imageURL: directory, on: device) { _ in }
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Could not clear Wallet cache (.cache)")
        }
    }

    func testOkFalseThrowsItsError() async throws {
        let engine = try engine(printing: [#"{"ok": false, "error": "Image file not found"}"#], exitCode: 0)
        do {
            try await engine.flash(card: card, imageURL: directory, on: device) { _ in }
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Image file not found")
        }
    }
}

final class LibraryStoreTests: XCTestCase {
    func testStateRoundTripsAndImportedImageIsCopied() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("walletbloom-library-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LibraryStore(directory: directory)

        let id = UUID()
        let fileName = try store.saveImage(Data([1, 2, 3]), id: id)

        var state = LibraryState()
        state.scannedCardHashes = ["abc"]
        state.appliedSkinIDs = ["abc": id]
        state.importedSkins = [.init(id: id, name: "My Skin", fileName: fileName)]
        try store.save(state)

        let loaded = store.load()
        XCTAssertEqual(loaded.scannedCardHashes, ["abc"])
        XCTAssertEqual(loaded.appliedSkinIDs["abc"], id)
        guard case .localImage(let url) = store.skin(for: loaded.importedSkins[0]).artwork else { return XCTFail("expected local image") }
        XCTAssertEqual(try Data(contentsOf: url), Data([1, 2, 3]), "保存的卡面图片应能从 Skins 目录读回")
    }
}

private final class LockedLines: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    var values: [String] { lock.lock(); defer { lock.unlock() }; return storage }
    func append(_ value: String) { lock.lock(); storage.append(value); lock.unlock() }
}

final class LibraryStateCompatibilityTests: XCTestCase {
    func testOldLibraryWithoutCardNamesStillLoads() throws {
        // 上一个版本写出的 library.json 没有 cardNames 字段。
        let json = #"{"appliedSkinIDs":{"abc":"8A7D5C30-19E4-4EC8-9C5E-000000000101"},"hiddenCardHashes":["junk"],"importedSkins":[],"scannedCardHashes":["abc"]}"#
        let state = try JSONDecoder().decode(LibraryState.self, from: Data(json.utf8))
        XCTAssertEqual(state.scannedCardHashes, ["abc"])
        XCTAssertEqual(state.hiddenCardHashes, ["junk"])
        XCTAssertEqual(state.appliedSkinIDs["abc"], UUID(uuidString: "8A7D5C30-19E4-4EC8-9C5E-000000000101"))
        XCTAssertEqual(state.cardNames, [:])
    }
}

final class BuiltInSkinRendererTests: XCTestCase {
    func testRendersExactWalletPixelSize() throws {
        let url = try BuiltInSkinRenderer.render(colors: ["F6B7C8", "D9779B"])
        defer { try? FileManager.default.removeItem(at: url) }
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: url)))
        XCTAssertEqual(bitmap.pixelsWide, 1536)
        XCTAssertEqual(bitmap.pixelsHigh, 969)
    }
}

final class CardArtworkCropperTests: XCTestCase {
    private let viewport = CGSize(width: 480, height: 480 / WalletCard.artworkAspectRatio)

    func testDefaultCropIsCenteredAndKeepsCardRatio() {
        // 4000×2000 的宽图：默认铺满取景框，左右各裁掉一部分。
        let rect = CardArtworkCropper.cropRect(imageSize: CGSize(width: 4000, height: 2000), viewport: viewport, zoom: 1, offset: .zero)
        XCTAssertEqual(rect.height, 2000, accuracy: 1)
        XCTAssertEqual(rect.width / rect.height, WalletCard.artworkAspectRatio, accuracy: 0.01)
        XCTAssertEqual(rect.midX, 2000, accuracy: 1)
    }

    func testOffsetCannotRevealEmptySpace() {
        // 往右拖得再远，裁剪区域也不会超出图片左边界。
        let rect = CardArtworkCropper.cropRect(imageSize: CGSize(width: 4000, height: 2000), viewport: viewport, zoom: 1, offset: CGSize(width: 10_000, height: 0))
        XCTAssertEqual(rect.minX, 0, accuracy: 1)
    }

    func testZoomShrinksTheCropRegion() {
        let size = CGSize(width: 3000, height: 3000)
        let normal = CardArtworkCropper.cropRect(imageSize: size, viewport: viewport, zoom: 1, offset: .zero)
        let zoomed = CardArtworkCropper.cropRect(imageSize: size, viewport: viewport, zoom: 2, offset: .zero)
        XCTAssertEqual(zoomed.width, normal.width / 2, accuracy: 2)
    }

    func testRenderOutputsWalletPixelSize() throws {
        let context = CGContext(data: nil, width: 800, height: 600, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
        let image = context.makeImage()!
        let rect = CardArtworkCropper.cropRect(imageSize: CGSize(width: 800, height: 600), viewport: viewport, zoom: 1, offset: .zero)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: CardArtworkCropper.renderPNG(image, cropRect: rect)))
        XCTAssertEqual(bitmap.pixelsWide, 1536)
        XCTAssertEqual(bitmap.pixelsHigh, 969)
    }
}
