// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PDFConverter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PDFConverter", targets: ["PDFConverter"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PDFConverter",
            sources: ["PDFConverterApp.swift", "ContentView.swift", "PDFConverterViewModel.swift"],
            swiftSettings: [
                .unsafeFlags(["-framework", "AppKit"])
            ]
        )
    ]
) 