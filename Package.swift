// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SquishPDF",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SquishPDF",
            targets: ["SquishPDF"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SquishPDF",
            dependencies: [],
            path: "Sources/SquishPDF",
            swiftSettings: [
                .unsafeFlags(["-framework", "AppKit"])
            ]
        )
    ]
)
