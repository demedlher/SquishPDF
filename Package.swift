// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DemedPlayer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DemedPlayer",
            targets: ["DemedPlayer"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DemedPlayer",
            dependencies: [],
            swiftSettings: [
                .unsafeFlags(["-framework", "AppKit"])
            ]
        )
    ]
) 