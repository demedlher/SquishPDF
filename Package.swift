// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PDFConverter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "PDFConverter",
            targets: ["PDFConverter"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PDFConverter",
            dependencies: [],
            path: "Sources/PDFConverter",
            swiftSettings: [
                .unsafeFlags(["-framework", "AppKit"])
            ]
        )
    ]
)
