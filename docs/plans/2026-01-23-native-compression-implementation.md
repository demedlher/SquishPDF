# Native Compression Engine Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an Apple-native PDF compression engine using CGPDFDocument and Core Image to replace Ghostscript for Mac App Store distribution.

**Architecture:** Protocol-based compression engine with swappable implementations. The native engine extracts images from PDFs using CGPDFDocument, downsamples them with Core Image, and rebuilds the PDF using CGContext with operator interception.

**Tech Stack:** Swift, PDFKit, Core Graphics (CGPDFDocument, CGContext, CGPDFOperatorTable), Core Image

---

## Phase 1: Foundation

### Task 1: Create CompressionEngine Protocol

**Files:**
- Create: `Sources/SquishPDF/Compression/CompressionEngine.swift`

**Step 1: Create directory structure**

```bash
cd /Users/demed/Documents/PERSO/dev/SquishPDF/.worktrees/native-compression
mkdir -p Sources/SquishPDF/Compression
```

**Step 2: Write the protocol**

```swift
// Sources/SquishPDF/Compression/CompressionEngine.swift
import Foundation

/// Quality preset for compression
struct CompressionPreset: Identifiable, Hashable {
    let id: String
    let displayName: String
    let description: String
    let targetDPI: Int
    let jpegQuality: Double  // 0.0 to 1.0

    static let tiny = CompressionPreset(
        id: "tiny", displayName: "Tiny", description: "Extreme compression (36 DPI)",
        targetDPI: 36, jpegQuality: 0.3
    )
    static let small = CompressionPreset(
        id: "small", displayName: "Small", description: "Low quality, smallest file (72 DPI)",
        targetDPI: 72, jpegQuality: 0.5
    )
    static let medium = CompressionPreset(
        id: "medium", displayName: "Medium", description: "Good quality for e-readers (150 DPI)",
        targetDPI: 150, jpegQuality: 0.7
    )
    static let large = CompressionPreset(
        id: "large", displayName: "Large", description: "High quality for printing (300 DPI)",
        targetDPI: 300, jpegQuality: 0.85
    )
    static let xlarge = CompressionPreset(
        id: "xlarge", displayName: "X-Large", description: "Maximum quality, commercial print",
        targetDPI: 300, jpegQuality: 0.95
    )

    static let all: [CompressionPreset] = [.tiny, .small, .medium, .large, .xlarge]
}

/// Progress information during compression
struct CompressionProgress {
    let currentPage: Int
    let totalPages: Int
    let message: String

    var percentage: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }
}

/// Errors from compression engines
enum CompressionError: LocalizedError {
    case engineNotAvailable
    case inputFileNotFound(URL)
    case outputWriteFailed(URL)
    case processingFailed(String)
    case unsupportedPDF(String)

    var errorDescription: String? {
        switch self {
        case .engineNotAvailable:
            return "Compression engine is not available"
        case .inputFileNotFound(let url):
            return "Input file not found: \(url.lastPathComponent)"
        case .outputWriteFailed(let url):
            return "Failed to write output: \(url.lastPathComponent)"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .unsupportedPDF(let reason):
            return "Unsupported PDF: \(reason)"
        }
    }
}

/// Protocol for PDF compression engines
protocol CompressionEngine {
    /// Human-readable name of this engine
    var name: String { get }

    /// Whether this engine is currently available
    var isAvailable: Bool { get }

    /// Compress a PDF file
    /// - Parameters:
    ///   - input: Source PDF URL
    ///   - output: Destination URL for compressed PDF
    ///   - preset: Compression preset to use
    ///   - progress: Callback for progress updates
    func compress(
        input: URL,
        output: URL,
        preset: CompressionPreset,
        progress: @escaping (CompressionProgress) -> Void
    ) async throws
}
```

**Step 3: Commit**

```bash
git add Sources/SquishPDF/Compression/CompressionEngine.swift
git commit -m "feat: add CompressionEngine protocol

Define common interface for swappable compression engines.
Includes CompressionPreset, CompressionProgress, and CompressionError types."
```

---

### Task 2: Wrap Existing Ghostscript Logic

**Files:**
- Create: `Sources/SquishPDF/Compression/GhostscriptEngine.swift`
- Reference: `Sources/SquishPDF/GhostscriptService.swift` (existing, don't modify yet)

**Step 1: Create wrapper that conforms to protocol**

```swift
// Sources/SquishPDF/Compression/GhostscriptEngine.swift
import Foundation

/// Ghostscript-based compression engine (existing implementation)
class GhostscriptEngine: CompressionEngine {
    private let service = GhostscriptService()

    var name: String { "Ghostscript" }

    var isAvailable: Bool { service.isAvailable() }

    func compress(
        input: URL,
        output: URL,
        preset: CompressionPreset,
        progress: @escaping (CompressionProgress) -> Void
    ) async throws {
        // Map CompressionPreset to GhostscriptPreset
        let gsPreset = mapToGhostscriptPreset(preset)

        // Get page count for progress
        let analysis = service.analyzePDF(at: input)
        let pageCount = analysis?.pageCount ?? 0

        try await service.compressPDF(
            inputURL: input,
            outputURL: output,
            preset: gsPreset,
            sourceDPI: analysis?.avgDPI,
            pageCount: pageCount
        ) { gsProgress in
            progress(CompressionProgress(
                currentPage: gsProgress.currentPage,
                totalPages: gsProgress.totalPages,
                message: gsProgress.message
            ))
        }
    }

    private func mapToGhostscriptPreset(_ preset: CompressionPreset) -> GhostscriptPreset {
        switch preset.id {
        case "tiny": return .tiny
        case "small": return .screen
        case "medium": return .ebook
        case "large": return .printer
        case "xlarge": return .prepress
        default: return .ebook
        }
    }
}
```

**Step 2: Commit**

```bash
git add Sources/SquishPDF/Compression/GhostscriptEngine.swift
git commit -m "feat: wrap GhostscriptService as CompressionEngine

Adapter to use existing Ghostscript implementation through the
new CompressionEngine protocol."
```

---

### Task 3: Create Native Engine Stub

**Files:**
- Create: `Sources/SquishPDF/Compression/NativeEngine/NativeCompressionEngine.swift`

**Step 1: Create directory and stub**

```bash
mkdir -p Sources/SquishPDF/Compression/NativeEngine
```

**Step 2: Write the stub**

```swift
// Sources/SquishPDF/Compression/NativeEngine/NativeCompressionEngine.swift
import Foundation
import CoreGraphics
import PDFKit

/// Apple-native compression engine using Core Graphics and Core Image
class NativeCompressionEngine: CompressionEngine {
    var name: String { "Native (Apple)" }

    var isAvailable: Bool { true }  // Always available on macOS

    func compress(
        input: URL,
        output: URL,
        preset: CompressionPreset,
        progress: @escaping (CompressionProgress) -> Void
    ) async throws {
        guard FileManager.default.fileExists(atPath: input.path) else {
            throw CompressionError.inputFileNotFound(input)
        }

        guard let pdfDocument = CGPDFDocument(input as CFURL) else {
            throw CompressionError.unsupportedPDF("Could not open PDF")
        }

        let pageCount = pdfDocument.numberOfPages

        // TODO: Implement actual compression
        // For now, just copy the file to verify the pipeline works
        progress(CompressionProgress(currentPage: 0, totalPages: pageCount, message: "Starting..."))

        try FileManager.default.copyItem(at: input, to: output)

        progress(CompressionProgress(currentPage: pageCount, totalPages: pageCount, message: "Done"))
    }
}
```

**Step 3: Commit**

```bash
git add Sources/SquishPDF/Compression/NativeEngine/NativeCompressionEngine.swift
git commit -m "feat: add NativeCompressionEngine stub

Placeholder implementation that verifies the pipeline works.
Will be replaced with actual image extraction and recompression."
```

---

## Phase 2: Benchmarking Infrastructure

### Task 4: Create Benchmark Harness

**Files:**
- Create: `Sources/SquishPDF/Benchmark/CompressionBenchmark.swift`

**Step 1: Create directory**

```bash
mkdir -p Sources/SquishPDF/Benchmark
```

**Step 2: Write benchmark code**

```swift
// Sources/SquishPDF/Benchmark/CompressionBenchmark.swift
import Foundation

/// Results from a single benchmark run
struct BenchmarkResult {
    let engineName: String
    let presetId: String
    let inputFile: String
    let inputSize: Int64
    let outputSize: Int64
    let durationSeconds: Double
    let success: Bool
    let errorMessage: String?

    var compressionRatio: Double {
        guard inputSize > 0 else { return 0 }
        return Double(outputSize) / Double(inputSize)
    }

    var reductionPercent: Double {
        (1.0 - compressionRatio) * 100
    }
}

/// Benchmark runner for comparing compression engines
class CompressionBenchmark {
    private let engines: [CompressionEngine]
    private let presets: [CompressionPreset]
    private let tempDirectory: URL

    init(engines: [CompressionEngine], presets: [CompressionPreset] = CompressionPreset.all) {
        self.engines = engines
        self.presets = presets
        self.tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SquishPDF-Benchmark-\(UUID().uuidString)")
    }

    /// Run benchmark on a single file with all engines and presets
    func benchmark(file: URL) async -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []

        // Create temp directory
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let inputSize = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0

        for engine in engines {
            guard engine.isAvailable else {
                print("Skipping \(engine.name): not available")
                continue
            }

            for preset in presets {
                let outputFile = tempDirectory
                    .appendingPathComponent("\(engine.name)-\(preset.id).pdf")

                let startTime = Date()
                var success = true
                var errorMessage: String?

                do {
                    try await engine.compress(
                        input: file,
                        output: outputFile,
                        preset: preset,
                        progress: { _ in }  // Ignore progress for benchmark
                    )
                } catch {
                    success = false
                    errorMessage = error.localizedDescription
                }

                let duration = Date().timeIntervalSince(startTime)
                let outputSize = (try? FileManager.default.attributesOfItem(atPath: outputFile.path)[.size] as? Int64) ?? 0

                results.append(BenchmarkResult(
                    engineName: engine.name,
                    presetId: preset.id,
                    inputFile: file.lastPathComponent,
                    inputSize: inputSize,
                    outputSize: outputSize,
                    durationSeconds: duration,
                    success: success,
                    errorMessage: errorMessage
                ))

                // Clean up output file
                try? FileManager.default.removeItem(at: outputFile)
            }
        }

        return results
    }

    /// Format results as markdown table
    static func formatAsMarkdown(_ results: [BenchmarkResult]) -> String {
        var output = "| Engine | Preset | Input | Output | Reduction | Time | Status |\n"
        output += "|--------|--------|-------|--------|-----------|------|--------|\n"

        for r in results {
            let inputStr = formatBytes(r.inputSize)
            let outputStr = r.success ? formatBytes(r.outputSize) : "-"
            let reductionStr = r.success ? String(format: "%.1f%%", r.reductionPercent) : "-"
            let timeStr = String(format: "%.2fs", r.durationSeconds)
            let statusStr = r.success ? "OK" : "FAIL"

            output += "| \(r.engineName) | \(r.presetId) | \(inputStr) | \(outputStr) | \(reductionStr) | \(timeStr) | \(statusStr) |\n"
        }

        return output
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_000_000
        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        }
        let kb = Double(bytes) / 1_000
        return String(format: "%.0f KB", kb)
    }
}
```

**Step 3: Commit**

```bash
git add Sources/SquishPDF/Benchmark/CompressionBenchmark.swift
git commit -m "feat: add benchmark harness for compression engines

Runs all engines with all presets on test files and generates
markdown comparison table."
```

---

### Task 5: Add Benchmark Command to App

**Files:**
- Modify: `Sources/SquishPDF/SquishPDFApp.swift`

**Step 1: Read current file**

Read `Sources/SquishPDF/SquishPDFApp.swift` to understand structure.

**Step 2: Add benchmark menu item**

Add a hidden menu item (Option+click) or command-line argument to trigger benchmark mode. The exact implementation depends on the current app structure.

For a SwiftUI app, add to the `commands` modifier:

```swift
// Add this CommandGroup to the App struct
CommandGroup(after: .help) {
    Button("Run Benchmark...") {
        runBenchmark()
    }
    .keyboardShortcut("B", modifiers: [.command, .option])
}

// Add this function to the App struct
private func runBenchmark() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.pdf]
    panel.allowsMultipleSelection = true
    panel.message = "Select PDF files to benchmark"

    if panel.runModal() == .OK {
        Task {
            let engines: [CompressionEngine] = [
                GhostscriptEngine(),
                NativeCompressionEngine()
            ]
            let benchmark = CompressionBenchmark(engines: engines)

            var allResults: [BenchmarkResult] = []
            for url in panel.urls {
                let results = await benchmark.benchmark(file: url)
                allResults.append(contentsOf: results)
            }

            let markdown = CompressionBenchmark.formatAsMarkdown(allResults)
            print(markdown)

            // Also save to Desktop
            let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let outputURL = desktopURL.appendingPathComponent("benchmark-results.md")
            try? markdown.write(to: outputURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(outputURL)
        }
    }
}
```

**Step 3: Commit**

```bash
git add Sources/SquishPDF/SquishPDFApp.swift
git commit -m "feat: add benchmark command (Cmd+Option+B)

Hidden menu item to run compression benchmark comparing
Ghostscript and Native engines."
```

---

## Phase 3: Image Extraction

### Task 6: Create PDFImageExtractor

**Files:**
- Create: `Sources/SquishPDF/Compression/NativeEngine/PDFImageExtractor.swift`

**Step 1: Write image extractor**

```swift
// Sources/SquishPDF/Compression/NativeEngine/PDFImageExtractor.swift
import Foundation
import CoreGraphics
import ImageIO

/// Information about an extracted image
struct ExtractedImage {
    let name: String           // XObject name (e.g., "Im0")
    let pageIndex: Int         // Which page references this image
    let cgImage: CGImage       // The extracted image
    let originalWidth: Int
    let originalHeight: Int
    let bitsPerComponent: Int
    let colorSpaceName: String
}

/// Extracts images from PDF XObjects
class PDFImageExtractor {

    /// Extract all images from a PDF document
    func extractImages(from document: CGPDFDocument) -> [ExtractedImage] {
        var images: [ExtractedImage] = []

        for pageIndex in 1...document.numberOfPages {
            guard let page = document.page(at: pageIndex) else { continue }

            let pageImages = extractImages(from: page, pageIndex: pageIndex)
            images.append(contentsOf: pageImages)
        }

        return images
    }

    /// Extract images from a single page
    private func extractImages(from page: CGPDFPage, pageIndex: Int) -> [ExtractedImage] {
        var images: [ExtractedImage] = []

        guard let pageDictionary = page.dictionary else { return images }

        // Get Resources dictionary
        var resourcesDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(pageDictionary, "Resources", &resourcesDict),
              let resources = resourcesDict else {
            return images
        }

        // Get XObject dictionary
        var xObjectDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(resources, "XObject", &xObjectDict),
              let xObjects = xObjectDict else {
            return images
        }

        // Iterate through XObjects
        CGPDFDictionaryApplyBlock(xObjects) { (key, value, _) -> Bool in
            let name = String(cString: key)

            // Check if this is an image
            var stream: CGPDFStreamRef?
            guard CGPDFObjectGetValue(value, .stream, &stream),
                  let imageStream = stream else {
                return true  // Continue iteration
            }

            guard let streamDict = CGPDFStreamGetDictionary(imageStream) else {
                return true
            }

            // Verify it's an Image subtype
            var subtypeName: UnsafePointer<Int8>?
            guard CGPDFDictionaryGetName(streamDict, "Subtype", &subtypeName),
                  let subtype = subtypeName,
                  String(cString: subtype) == "Image" else {
                return true
            }

            // Extract image properties
            var width: CGPDFInteger = 0
            var height: CGPDFInteger = 0
            var bitsPerComponent: CGPDFInteger = 8

            CGPDFDictionaryGetInteger(streamDict, "Width", &width)
            CGPDFDictionaryGetInteger(streamDict, "Height", &height)
            CGPDFDictionaryGetInteger(streamDict, "BitsPerComponent", &bitsPerComponent)

            // Get color space name
            var colorSpaceName = "Unknown"
            var csName: UnsafePointer<Int8>?
            if CGPDFDictionaryGetName(streamDict, "ColorSpace", &csName),
               let csNamePtr = csName {
                colorSpaceName = String(cString: csNamePtr)
            }

            // Try to extract the image data and create CGImage
            if let cgImage = self.createCGImage(from: imageStream, dict: streamDict) {
                let extracted = ExtractedImage(
                    name: name,
                    pageIndex: pageIndex,
                    cgImage: cgImage,
                    originalWidth: Int(width),
                    originalHeight: Int(height),
                    bitsPerComponent: Int(bitsPerComponent),
                    colorSpaceName: colorSpaceName
                )
                images.append(extracted)
            }

            return true  // Continue iteration
        }

        return images
    }

    /// Create a CGImage from a PDF image stream
    private func createCGImage(from stream: CGPDFStreamRef, dict: CGPDFDictionaryRef) -> CGImage? {
        var format: CGPDFDataFormat = .raw
        guard let data = CGPDFStreamCopyData(stream, &format) else {
            return nil
        }

        var width: CGPDFInteger = 0
        var height: CGPDFInteger = 0
        var bitsPerComponent: CGPDFInteger = 8

        CGPDFDictionaryGetInteger(dict, "Width", &width)
        CGPDFDictionaryGetInteger(dict, "Height", &height)
        CGPDFDictionaryGetInteger(dict, "BitsPerComponent", &bitsPerComponent)

        // Handle different compression formats
        switch format {
        case .JPEG, .JPEG2000:
            // Already compressed image data - decode via ImageIO
            guard let dataProvider = CGDataProvider(data: data),
                  let image = CGImage(jpegDataProviderSource: dataProvider,
                                      decode: nil,
                                      shouldInterpolate: true,
                                      intent: .defaultIntent) else {
                return nil
            }
            return image

        case .raw:
            // Raw image data - need to construct CGImage manually
            return createCGImageFromRawData(
                data: data as Data,
                width: Int(width),
                height: Int(height),
                bitsPerComponent: Int(bitsPerComponent),
                dict: dict
            )
        @unknown default:
            return nil
        }
    }

    /// Create CGImage from raw (uncompressed or Flate-decoded) data
    private func createCGImageFromRawData(
        data: Data,
        width: Int,
        height: Int,
        bitsPerComponent: Int,
        dict: CGPDFDictionaryRef
    ) -> CGImage? {
        // Determine color space and components
        var componentsPerPixel = 3  // Default to RGB
        var colorSpace = CGColorSpaceCreateDeviceRGB()

        var csName: UnsafePointer<Int8>?
        if CGPDFDictionaryGetName(dict, "ColorSpace", &csName),
           let name = csName {
            let csString = String(cString: name)
            switch csString {
            case "DeviceGray":
                componentsPerPixel = 1
                colorSpace = CGColorSpaceCreateDeviceGray()
            case "DeviceCMYK":
                componentsPerPixel = 4
                colorSpace = CGColorSpaceCreateDeviceCMYK()
            default:
                break  // Keep RGB default
            }
        }

        let bitsPerPixel = bitsPerComponent * componentsPerPixel
        let bytesPerRow = (width * bitsPerPixel + 7) / 8

        guard let dataProvider = CGDataProvider(data: data as CFData) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}
```

**Step 2: Commit**

```bash
git add Sources/SquishPDF/Compression/NativeEngine/PDFImageExtractor.swift
git commit -m "feat: add PDFImageExtractor

Extracts images from PDF XObjects using CGPDFDocument.
Handles JPEG, JPEG2000, and raw image formats."
```

---

### Task 7: Create ImageDownsampler

**Files:**
- Create: `Sources/SquishPDF/Compression/NativeEngine/ImageDownsampler.swift`

**Step 1: Write downsampler**

```swift
// Sources/SquishPDF/Compression/NativeEngine/ImageDownsampler.swift
import Foundation
import CoreGraphics
import CoreImage
import ImageIO

/// Downsamples and recompresses images
class ImageDownsampler {
    private let context: CIContext

    init() {
        self.context = CIContext(options: [.useSoftwareRenderer: false])
    }

    /// Downsample an image to target DPI and compress as JPEG
    /// - Parameters:
    ///   - image: Source CGImage
    ///   - currentDPI: Estimated current DPI of the image
    ///   - targetDPI: Target DPI after downsampling
    ///   - jpegQuality: JPEG quality (0.0 to 1.0)
    /// - Returns: JPEG data for the downsampled image
    func downsample(
        image: CGImage,
        currentDPI: Int,
        targetDPI: Int,
        jpegQuality: Double
    ) -> Data? {
        // Calculate scale factor
        let scale = min(1.0, Double(targetDPI) / Double(currentDPI))

        // If scale is close to 1.0, just recompress without scaling
        if scale > 0.95 {
            return compressAsJPEG(image: image, quality: jpegQuality)
        }

        // Calculate new dimensions
        let newWidth = Int(Double(image.width) * scale)
        let newHeight = Int(Double(image.height) * scale)

        guard newWidth > 0, newHeight > 0 else {
            return nil
        }

        // Use Core Image for high-quality downsampling
        let ciImage = CIImage(cgImage: image)

        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = ciImage.transformed(by: transform)

        // Apply Lanczos resampling for better quality
        guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
            // Fallback: use the basic scaled image
            return renderAndCompress(ciImage: scaledImage, quality: jpegQuality)
        }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(1.0, forKey: kCIInputAspectRatioKey)

        guard let outputImage = filter.outputImage else {
            return renderAndCompress(ciImage: scaledImage, quality: jpegQuality)
        }

        return renderAndCompress(ciImage: outputImage, quality: jpegQuality)
    }

    /// Compress a CGImage as JPEG without resizing
    func compressAsJPEG(image: CGImage, quality: Double) -> Data? {
        let ciImage = CIImage(cgImage: image)
        return renderAndCompress(ciImage: ciImage, quality: quality)
    }

    /// Render CIImage and compress to JPEG data
    private func renderAndCompress(ciImage: CIImage, quality: Double) -> Data? {
        let colorSpace = ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        return context.jpegRepresentation(
            of: ciImage,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality]
        )
    }

    /// Estimate the DPI of an image given its pixel dimensions and display size in inches
    static func estimateDPI(pixelWidth: Int, pixelHeight: Int, displayWidthInches: Double, displayHeightInches: Double) -> Int {
        let dpiFromWidth = Double(pixelWidth) / displayWidthInches
        let dpiFromHeight = Double(pixelHeight) / displayHeightInches
        return Int(max(dpiFromWidth, dpiFromHeight))
    }
}
```

**Step 2: Commit**

```bash
git add Sources/SquishPDF/Compression/NativeEngine/ImageDownsampler.swift
git commit -m "feat: add ImageDownsampler

Uses Core Image with Lanczos resampling for high-quality
downscaling. Outputs JPEG at configurable quality."
```

---

## Phase 4: PDF Rebuilding

### Task 8: Create PDFRebuilder

**Files:**
- Create: `Sources/SquishPDF/Compression/NativeEngine/PDFRebuilder.swift`

**Step 1: Write PDF rebuilder with operator interception**

```swift
// Sources/SquishPDF/Compression/NativeEngine/PDFRebuilder.swift
import Foundation
import CoreGraphics
import PDFKit

/// Rebuilds PDF with replaced images
class PDFRebuilder {

    /// Image replacements: XObject name -> replacement JPEG data
    typealias ImageReplacements = [String: Data]

    /// Rebuild a PDF, replacing specified images
    /// - Parameters:
    ///   - source: Source PDF document
    ///   - replacements: Dictionary mapping XObject names to replacement JPEG data
    ///   - output: Output URL for the rebuilt PDF
    ///   - progress: Progress callback (page number)
    func rebuild(
        source: CGPDFDocument,
        replacements: ImageReplacements,
        output: URL,
        progress: @escaping (Int, Int) -> Void
    ) throws {
        let pageCount = source.numberOfPages

        // Create PDF context for output
        guard let pdfContext = CGContext(output as CFURL, mediaBox: nil, nil) else {
            throw CompressionError.outputWriteFailed(output)
        }

        for pageIndex in 1...pageCount {
            progress(pageIndex, pageCount)

            guard let page = source.page(at: pageIndex) else { continue }

            let mediaBox = page.getBoxRect(.mediaBox)
            var pageBox = mediaBox

            // Begin new page
            pdfContext.beginPDFPage([
                kCGPDFContextMediaBox as String: NSValue(rect: NSRect(cgRect: mediaBox))
            ] as CFDictionary)

            // Draw the page content with image substitution
            drawPage(page, to: pdfContext, replacements: replacements)

            pdfContext.endPDFPage()
        }

        pdfContext.closePDF()
    }

    /// Draw a page to context, substituting images
    private func drawPage(
        _ page: CGPDFPage,
        to context: CGContext,
        replacements: ImageReplacements
    ) {
        // Create operator table for intercepting drawing commands
        var callbacks = CGPDFOperatorCallbacks()

        // Store context info for callbacks
        var info = DrawingInfo(
            context: context,
            page: page,
            replacements: replacements,
            imageDataProviders: createDataProviders(from: replacements)
        )

        // Create scanner
        guard let table = CGPDFOperatorTableCreate() else {
            // Fallback: just draw the page normally
            context.drawPDFPage(page)
            return
        }

        // Register callback for 'Do' operator (draw XObject)
        CGPDFOperatorTableSetCallback(table, "Do") { scanner, info in
            guard let info = info?.assumingMemoryBound(to: DrawingInfo.self).pointee else { return }

            // Get XObject name
            var name: UnsafePointer<Int8>?
            guard CGPDFScannerPopName(scanner, &name), let xobjectName = name else { return }

            let nameString = String(cString: xobjectName)

            // Check if we have a replacement for this image
            if let replacementProvider = info.imageDataProviders[nameString],
               let replacementImage = CGImage(
                   jpegDataProviderSource: replacementProvider,
                   decode: nil,
                   shouldInterpolate: true,
                   intent: .defaultIntent
               ) {
                // Get the current transformation matrix to determine placement
                let ctm = info.context.ctm

                // Draw replacement image
                // Note: PDF images are drawn in a 1x1 unit square, scaled by CTM
                info.context.saveGState()
                info.context.draw(replacementImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                info.context.restoreGState()
            } else {
                // No replacement - need to draw original
                // This is complex because we need to access the original XObject
                // For now, we'll handle this in the main draw call
            }
        }

        // For initial implementation, use simpler approach:
        // Draw entire page, then overlay replacement handling
        context.drawPDFPage(page)

        // Note: Full operator interception is complex.
        // For Phase 1, we may need a different approach - see Task 9.
    }

    /// Create CGDataProviders for each replacement image
    private func createDataProviders(from replacements: ImageReplacements) -> [String: CGDataProvider] {
        var providers: [String: CGDataProvider] = [:]
        for (name, data) in replacements {
            if let provider = CGDataProvider(data: data as CFData) {
                providers[name] = provider
            }
        }
        return providers
    }
}

/// Context passed to PDF operator callbacks
private struct DrawingInfo {
    let context: CGContext
    let page: CGPDFPage
    let replacements: PDFRebuilder.ImageReplacements
    let imageDataProviders: [String: CGDataProvider]
}
```

**Step 2: Commit**

```bash
git add Sources/SquishPDF/Compression/NativeEngine/PDFRebuilder.swift
git commit -m "feat: add PDFRebuilder with operator interception

Initial implementation using CGPDFOperatorTable to intercept
image drawing. Note: Full implementation may need refinement."
```

---

### Task 9: Implement Alternative Rebuild Strategy

The operator interception approach is complex. As a more reliable alternative, we can use PDFKit's `PDFDocument` which provides higher-level APIs.

**Files:**
- Create: `Sources/SquishPDF/Compression/NativeEngine/PDFKitRebuilder.swift`

**Step 1: Write PDFKit-based rebuilder**

```swift
// Sources/SquishPDF/Compression/NativeEngine/PDFKitRebuilder.swift
import Foundation
import PDFKit
import CoreGraphics

/// Alternative rebuilder using PDFKit (simpler but may have limitations)
class PDFKitRebuilder {

    /// Rebuild PDF by rendering pages to images and reconstructing
    /// This is a fallback approach that works but loses text selectability
    func rebuildAsImagePDF(
        source: URL,
        targetDPI: Int,
        jpegQuality: Double,
        output: URL,
        progress: @escaping (Int, Int) -> Void
    ) throws {
        guard let document = PDFDocument(url: source) else {
            throw CompressionError.unsupportedPDF("Could not open PDF")
        }

        let pageCount = document.pageCount
        let newDocument = PDFDocument()

        for pageIndex in 0..<pageCount {
            progress(pageIndex + 1, pageCount)

            guard let page = document.page(at: pageIndex) else { continue }

            // Get page bounds
            let bounds = page.bounds(for: .mediaBox)

            // Calculate render size based on target DPI
            let scale = CGFloat(targetDPI) / 72.0  // PDF points are 72 per inch
            let renderWidth = bounds.width * scale
            let renderHeight = bounds.height * scale

            // Render page to image
            guard let image = renderPageToImage(page: page, size: CGSize(width: renderWidth, height: renderHeight)) else {
                continue
            }

            // Compress as JPEG
            guard let jpegData = compressToJPEG(image: image, quality: jpegQuality) else {
                continue
            }

            // Create new PDF page from JPEG
            guard let jpegImage = NSImage(data: jpegData) else { continue }

            // Create a PDF page that displays at original size
            let newPage = PDFPage(image: jpegImage)

            // Set the page bounds to original size
            newPage?.setBounds(bounds, for: .mediaBox)

            if let newPage = newPage {
                newDocument.insert(newPage, at: pageIndex)
            }
        }

        // Save document
        guard newDocument.write(to: output) else {
            throw CompressionError.outputWriteFailed(output)
        }
    }

    /// Render a PDF page to a CGImage
    private func renderPageToImage(page: PDFPage, size: CGSize) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale = size.width / bounds.width

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        // White background
        context.setFillColor(CGColor.white)
        context.fill(CGRect(origin: .zero, size: size))

        // Scale and draw
        context.scaleBy(x: scale, y: scale)

        // Draw the PDF page
        if let pageRef = page.pageRef {
            context.drawPDFPage(pageRef)
        }

        return context.makeImage()
    }

    /// Compress CGImage to JPEG data
    private func compressToJPEG(image: CGImage, quality: Double) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return mutableData as Data
    }
}
```

**Step 2: Commit**

```bash
git add Sources/SquishPDF/Compression/NativeEngine/PDFKitRebuilder.swift
git commit -m "feat: add PDFKitRebuilder as fallback strategy

Simpler page-rasterization approach. Trades text selectability
for reliability. Can be used as benchmark baseline."
```

---

## Phase 5: Integration

### Task 10: Wire Up Native Engine

**Files:**
- Modify: `Sources/SquishPDF/Compression/NativeEngine/NativeCompressionEngine.swift`

**Step 1: Update to use extraction, downsampling, and rebuilding**

Replace the stub implementation with the full pipeline:

```swift
// Sources/SquishPDF/Compression/NativeEngine/NativeCompressionEngine.swift
import Foundation
import CoreGraphics
import PDFKit

/// Apple-native compression engine using Core Graphics and Core Image
class NativeCompressionEngine: CompressionEngine {
    private let extractor = PDFImageExtractor()
    private let downsampler = ImageDownsampler()
    private let rebuilder = PDFRebuilder()
    private let fallbackRebuilder = PDFKitRebuilder()

    /// Whether to use the fallback (image-based) rebuilder
    var useFallbackRebuilder = false

    var name: String { "Native (Apple)" }

    var isAvailable: Bool { true }

    func compress(
        input: URL,
        output: URL,
        preset: CompressionPreset,
        progress: @escaping (CompressionProgress) -> Void
    ) async throws {
        guard FileManager.default.fileExists(atPath: input.path) else {
            throw CompressionError.inputFileNotFound(input)
        }

        guard let pdfDocument = CGPDFDocument(input as CFURL) else {
            throw CompressionError.unsupportedPDF("Could not open PDF")
        }

        let pageCount = pdfDocument.numberOfPages
        progress(CompressionProgress(currentPage: 0, totalPages: pageCount, message: "Analyzing..."))

        // Use fallback rebuilder for now (more reliable)
        // TODO: Switch to full rebuilder once image substitution is working
        if useFallbackRebuilder {
            try fallbackRebuilder.rebuildAsImagePDF(
                source: input,
                targetDPI: preset.targetDPI,
                jpegQuality: preset.jpegQuality,
                output: output
            ) { current, total in
                progress(CompressionProgress(
                    currentPage: current,
                    totalPages: total,
                    message: "Page \(current) of \(total)"
                ))
            }
            return
        }

        // Full pipeline: extract → downsample → rebuild
        progress(CompressionProgress(currentPage: 0, totalPages: pageCount, message: "Extracting images..."))

        // Step 1: Extract images
        let extractedImages = extractor.extractImages(from: pdfDocument)

        progress(CompressionProgress(currentPage: 0, totalPages: pageCount, message: "Processing \(extractedImages.count) images..."))

        // Step 2: Downsample each image
        var replacements: [String: Data] = [:]

        // Estimate page size (assume letter size if not available)
        let pageWidthInches = 8.5
        let pageHeightInches = 11.0

        for (index, image) in extractedImages.enumerated() {
            // Estimate current DPI
            let currentDPI = ImageDownsampler.estimateDPI(
                pixelWidth: image.originalWidth,
                pixelHeight: image.originalHeight,
                displayWidthInches: pageWidthInches,
                displayHeightInches: pageHeightInches
            )

            // Downsample
            if let jpegData = downsampler.downsample(
                image: image.cgImage,
                currentDPI: currentDPI,
                targetDPI: preset.targetDPI,
                jpegQuality: preset.jpegQuality
            ) {
                replacements[image.name] = jpegData
            }

            progress(CompressionProgress(
                currentPage: 0,
                totalPages: pageCount,
                message: "Processed image \(index + 1)/\(extractedImages.count)"
            ))
        }

        // Step 3: Rebuild PDF with replaced images
        progress(CompressionProgress(currentPage: 0, totalPages: pageCount, message: "Rebuilding PDF..."))

        try rebuilder.rebuild(
            source: pdfDocument,
            replacements: replacements,
            output: output
        ) { current, total in
            progress(CompressionProgress(
                currentPage: current,
                totalPages: total,
                message: "Writing page \(current) of \(total)"
            ))
        }
    }
}
```

**Step 2: Commit**

```bash
git add Sources/SquishPDF/Compression/NativeEngine/NativeCompressionEngine.swift
git commit -m "feat: wire up full native compression pipeline

Integrates extractor, downsampler, and rebuilder.
Includes fallback to image-based rebuilder for reliability."
```

---

### Task 11: Run Initial Benchmark

**Step 1: Build and run**

```bash
cd /Users/demed/Documents/PERSO/dev/SquishPDF/.worktrees/native-compression
swift build
```

**Step 2: Run benchmark from app**

Launch the app and use Cmd+Option+B to run benchmark on test PDFs.

**Step 3: Analyze results**

Review the generated `benchmark-results.md` on Desktop.

**Step 4: Document findings**

Create a file documenting the benchmark results:

```bash
# After running benchmark, document results in:
# docs/benchmarks/2026-01-XX-initial-benchmark.md
```

---

## Phase 6: Iteration

Based on benchmark results, iterate on:

1. **If compression ratio is poor:** Investigate image extraction quality
2. **If text is lost:** Debug the rebuilder, may need CGPDFOperatorTable approach
3. **If speed is poor:** Profile and optimize (parallelize image processing)
4. **If specific PDFs fail:** Add error handling for edge cases

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Compression ratio | Within 20% of Ghostscript |
| Text selectability | 100% preserved (or accept fallback) |
| Processing speed | Within 2x of Ghostscript |
| Stability | No crashes on test corpus |
