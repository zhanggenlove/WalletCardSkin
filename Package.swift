// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WalletBloom",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "WalletBloom", targets: ["WalletBloom"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0")
    ],
    targets: [
        .executableTarget(
            name: "WalletBloom",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/WalletBloom",
            // Sparkle.framework 由 scripts/package_app.sh 放进 Contents/Frameworks。
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "WalletBloomTests",
            dependencies: ["WalletBloom"],
            path: "Tests/WalletBloomTests"
        )
    ]
)
