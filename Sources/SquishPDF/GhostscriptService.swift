import Foundation
import PDFKit

/// Ghostscript compression presets
enum GhostscriptPreset: String, CaseIterable, Identifiable {
    // Standard presets (ordered by compression aggressiveness)
    case tiny = "tiny"
    case screen = "screen"
    case ebook = "ebook"
    case printer = "printer"
    case prepress = "prepress"
    // Specialized presets
    case grayscale = "grayscale"
    case web = "web"

    var id: String { rawValue }

    /// Standard presets for general use
    static var standardPresets: [GhostscriptPreset] {
        [.tiny, .screen, .ebook, .printer, .prepress]
    }

    /// Specialized presets for specific use cases
    static var specializedPresets: [GhostscriptPreset] {
        [.grayscale, .web]
    }

    var displayName: String {
        switch self {
        case .tiny: return "Tiny"
        case .screen: return "Small"
        case .ebook: return "Medium"
        case .printer: return "Large"
        case .prepress: return "X-Large"
        case .grayscale: return "Grayscale"
        case .web: return "Web"
        }
    }

    var description: String {
        switch self {
        case .tiny: return "Extreme compression (36 DPI)"
        case .screen: return "Lowest quality, smallest file (72 DPI)"
        case .ebook: return "Good quality for e-readers (150 DPI)"
        case .printer: return "High quality for printing (300 DPI)"
        case .prepress: return "Maximum quality, commercial print"
        case .grayscale: return "Converts to grayscale (150 DPI)"
        case .web: return "Web-optimized, stripped metadata"
        }
    }

    /// Whether this is a specialized preset
    var isSpecialized: Bool {
        switch self {
        case .grayscale, .web: return true
        default: return false
        }
    }

    /// Ghostscript arguments for this preset
    var gsArguments: [String] {
        switch self {
        case .tiny:
            // Ultra-aggressive: 36 DPI, forced JPEG compression
            return [
                "-dPDFSETTINGS=/screen",
                "-dColorImageResolution=36",
                "-dGrayImageResolution=36",
                "-dMonoImageResolution=36",
                "-dColorImageDownsampleType=/Bicubic",
                "-dGrayImageDownsampleType=/Bicubic",
                "-dDetectDuplicateImages=true"
            ]
        case .screen:
            return ["-dPDFSETTINGS=/screen"]
        case .ebook:
            return ["-dPDFSETTINGS=/ebook"]
        case .printer:
            return ["-dPDFSETTINGS=/printer"]
        case .prepress:
            return ["-dPDFSETTINGS=/prepress"]
        case .grayscale:
            // Convert to grayscale at 150 DPI - great for graphics-heavy docs
            return [
                "-dPDFSETTINGS=/ebook",
                "-sColorConversionStrategy=Gray",
                "-dProcessColorModel=/DeviceGray",
                "-dDetectDuplicateImages=true",
                "-dRemoveUnusedResources=true"
            ]
        case .web:
            // Web-optimized: 72 DPI, stripped metadata, subset fonts
            return [
                "-dPDFSETTINGS=/screen",
                "-dDetectDuplicateImages=true",
                "-dRemoveUnusedResources=true",
                "-dSubsetFonts=true",
                "-dCompressFonts=true",
                "-dFastWebView=true"
            ]
        }
    }

    /// DPI value for this preset (for display purposes)
    var dpi: Int {
        switch self {
        case .tiny: return 36
        case .screen: return 72
        case .ebook: return 150
        case .printer: return 300
        case .prepress: return 300
        case .grayscale: return 150
        case .web: return 72
        }
    }

    /// Filename suffix (e.g., "medium-150dpi")
    var filenameSuffix: String {
        switch self {
        case .grayscale: return "grayscale-\(dpi)dpi"
        case .web: return "web-optimized"
        default: return "\(displayName.lowercased())-\(dpi)dpi"
        }
    }

    /// Estimated compression ratio range (min, max) as percentage of original size
    var estimatedRatioRange: (min: Double, max: Double) {
        switch self {
        case .tiny: return (0.02, 0.10)     // 2-10% of original (90-98% reduction)
        case .screen: return (0.05, 0.20)   // 5-20% of original (80-95% reduction)
        case .ebook: return (0.20, 0.40)    // 20-40% of original (60-80% reduction)
        case .printer: return (0.40, 0.70)  // 40-70% of original (30-60% reduction)
        case .prepress: return (0.70, 0.95) // 70-95% of original (5-30% reduction)
        case .grayscale: return (0.10, 0.30) // 10-30% of original (70-90% reduction)
        case .web: return (0.05, 0.20)      // 5-20% of original (80-95% reduction)
        }
    }

    /// Estimate output size range for a given input size
    func estimatedSizeRange(for inputSize: Int64) -> (min: Int64, max: Int64) {
        let range = estimatedRatioRange
        return (
            min: Int64(Double(inputSize) * range.min),
            max: Int64(Double(inputSize) * range.max)
        )
    }
}

/// Progress information parsed from Ghostscript output
struct GhostscriptProgress {
    let currentPage: Int
    let totalPages: Int
    let message: String

    var percentage: Int {
        guard totalPages > 0 else { return 0 }
        return min(100, (currentPage * 100) / totalPages)
    }
}

/// Results from analyzing a PDF's image content
struct PDFImageAnalysis {
    let imageCount: Int
    let minDPI: Int
    let maxDPI: Int
    let avgDPI: Int
    let pageWidthInches: Double
    let pageHeightInches: Double

    /// Estimate compression ratio for a given target DPI
    /// Returns a value between 0 and 1 (percentage of original size)
    func estimatedRatio(forTargetDPI targetDPI: Int) -> Double {
        guard avgDPI > 0 else { return 0.5 }  // Default if no images found

        if targetDPI >= avgDPI {
            // Target DPI is same or higher than source - minimal compression
            return 0.85
        }

        // Compression is roughly proportional to (targetDPI / sourceDPI)^2
        // because we're reducing both dimensions
        let ratio = Double(targetDPI) / Double(avgDPI)
        let compressionFactor = ratio * ratio

        // Add some overhead for PDF structure, fonts, etc. (typically 10-20% of file)
        let estimatedRatio = compressionFactor * 0.85 + 0.10

        // Clamp to reasonable range
        return min(0.95, max(0.02, estimatedRatio))
    }

    /// Check if a preset will provide meaningful compression
    func isPresetEffective(_ preset: GhostscriptPreset) -> Bool {
        let targetDPI = preset.dpi
        // Preset is effective if it's at least 20% lower than source DPI
        return targetDPI < Int(Double(avgDPI) * 0.8)
    }
}

/// Errors that can occur during Ghostscript operations
enum GhostscriptError: LocalizedError {
    case notBundled
    case inputNotFound(URL)
    case processFailed(exitCode: Int, message: String)
    case outputWriteFailed

    var errorDescription: String? {
        switch self {
        case .notBundled:
            return "Ghostscript is not properly installed. Please reinstall the application."
        case .inputNotFound(let url):
            return "PDF file not found: \(url.lastPathComponent)"
        case .processFailed(let code, let message):
            let cleanMessage = message.isEmpty ? "Unknown error" : message
            return "Compression failed (code \(code)): \(cleanMessage)"
        case .outputWriteFailed:
            return "Failed to write compressed PDF."
        }
    }
}

/// Service for invoking Ghostscript to compress PDFs
class GhostscriptService {

    /// Path to Ghostscript binary - prefers system installation for reliability
    private var gsPath: URL? {
        // Prefer Homebrew installation (Apple Silicon)
        let homebrewPath = URL(fileURLWithPath: "/opt/homebrew/bin/gs")
        if FileManager.default.isExecutableFile(atPath: homebrewPath.path) {
            return homebrewPath
        }

        // Try Intel Mac Homebrew path
        let homebrewIntelPath = URL(fileURLWithPath: "/usr/local/bin/gs")
        if FileManager.default.isExecutableFile(atPath: homebrewIntelPath.path) {
            return homebrewIntelPath
        }

        // Fall back to bundled Ghostscript
        let bundledPath = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Frameworks")
            .appendingPathComponent("Ghostscript")
            .appendingPathComponent("bin")
            .appendingPathComponent("gs")

        if FileManager.default.isExecutableFile(atPath: bundledPath.path) {
            return bundledPath
        }

        return nil
    }

    /// Path to bundled Ghostscript resources (for bundled gs only)
    private var gsResourcePath: URL? {
        let bundledResources = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Frameworks")
            .appendingPathComponent("Ghostscript")
            .appendingPathComponent("share")
            .appendingPathComponent("ghostscript")

        if FileManager.default.fileExists(atPath: bundledResources.path) {
            return bundledResources
        }
        return nil
    }

    /// Check if Ghostscript is available
    func isAvailable() -> Bool {
        gsPath != nil
    }

    /// Analyze a PDF to determine image DPI and estimate compression potential
    func analyzePDF(at url: URL) -> PDFImageAnalysis? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        // Convert to string for pattern matching (using latin1 to handle binary)
        guard let content = String(data: data, encoding: .isoLatin1) else { return nil }

        // Extract page dimensions from MediaBox (in points, 72 points = 1 inch)
        var pageWidthInches = 8.5  // Default letter size
        var pageHeightInches = 11.0

        if let mediaBoxMatch = content.range(of: #"/MediaBox\s*\[\s*[\d.]+\s+[\d.]+\s+([\d.]+)\s+([\d.]+)\s*\]"#, options: .regularExpression) {
            let mediaBoxStr = String(content[mediaBoxMatch])
            let numbers = mediaBoxStr.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Double($0) }
                .filter { $0 > 0 }
            if numbers.count >= 2 {
                // Last two numbers are typically width and height
                let width = numbers[numbers.count - 2]
                let height = numbers[numbers.count - 1]
                pageWidthInches = width / 72.0
                pageHeightInches = height / 72.0
            }
        }

        // Find images by looking for /Subtype /Image patterns with Width/Height
        var imageDPIs: [Int] = []

        // Pattern to find image objects with dimensions
        let objPattern = #"(\d+)\s+0\s+obj.*?endobj"#
        let regex = try? NSRegularExpression(pattern: objPattern, options: .dotMatchesLineSeparators)
        let nsContent = content as NSString

        regex?.enumerateMatches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length)) { match, _, _ in
            guard let match = match else { return }
            let objStr = nsContent.substring(with: match.range)

            // Check if this is an image object
            if objStr.contains("/Subtype") && objStr.contains("/Image") {
                // Extract width and height
                var width: Int?
                var height: Int?

                if let widthRange = objStr.range(of: #"/Width\s+(\d+)"#, options: .regularExpression) {
                    let widthStr = objStr[widthRange].components(separatedBy: CharacterSet.decimalDigits.inverted)
                        .compactMap { Int($0) }.first
                    width = widthStr
                }

                if let heightRange = objStr.range(of: #"/Height\s+(\d+)"#, options: .regularExpression) {
                    let heightStr = objStr[heightRange].components(separatedBy: CharacterSet.decimalDigits.inverted)
                        .compactMap { Int($0) }.first
                    height = heightStr
                }

                // Calculate DPI if we have dimensions (filter out tiny images)
                if let w = width, let h = height, w > 50, h > 50 {
                    // Estimate DPI assuming image could span the page
                    let dpiFromWidth = Double(w) / pageWidthInches
                    let dpiFromHeight = Double(h) / pageHeightInches
                    let estimatedDPI = Int(max(dpiFromWidth, dpiFromHeight))

                    // Filter reasonable DPI values (10 to 1200)
                    if estimatedDPI >= 10 && estimatedDPI <= 1200 {
                        imageDPIs.append(estimatedDPI)
                    }
                }
            }
        }

        // Calculate statistics
        guard !imageDPIs.isEmpty else {
            // No images found - return default analysis
            return PDFImageAnalysis(
                imageCount: 0,
                minDPI: 0,
                maxDPI: 0,
                avgDPI: 0,
                pageWidthInches: pageWidthInches,
                pageHeightInches: pageHeightInches
            )
        }

        let minDPI = imageDPIs.min() ?? 0
        let maxDPI = imageDPIs.max() ?? 0
        let avgDPI = imageDPIs.reduce(0, +) / imageDPIs.count

        return PDFImageAnalysis(
            imageCount: imageDPIs.count,
            minDPI: minDPI,
            maxDPI: maxDPI,
            avgDPI: avgDPI,
            pageWidthInches: pageWidthInches,
            pageHeightInches: pageHeightInches
        )
    }

    /// Get the number of pages in a PDF
    private func getPageCount(for url: URL) -> Int {
        guard let document = PDFDocument(url: url) else { return 0 }
        return document.pageCount
    }

    /// Compress PDF using specified preset
    func compressPDF(
        inputURL: URL,
        outputURL: URL,
        preset: GhostscriptPreset,
        progressHandler: @escaping (GhostscriptProgress) -> Void
    ) async throws {
        guard let gsExecutable = gsPath else {
            throw GhostscriptError.notBundled
        }

        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw GhostscriptError.inputNotFound(inputURL)
        }

        // Get total page count for progress tracking
        let totalPages = getPageCount(for: inputURL)

        let process = Process()
        process.executableURL = gsExecutable

        // Build Ghostscript arguments
        var arguments = [
            "-dNOPAUSE",
            "-dBATCH",
            "-dSAFER",
            "-sDEVICE=pdfwrite",
            "-dCompatibilityLevel=1.4"
        ]
        // Add preset-specific arguments
        arguments.append(contentsOf: preset.gsArguments)
        // Add output and input files
        arguments.append("-sOutputFile=\(outputURL.path)")
        arguments.append(inputURL.path)
        process.arguments = arguments

        // Set environment for bundled resources if available
        if let resourcePath = gsResourcePath {
            var env = ProcessInfo.processInfo.environment
            env["GS_LIB"] = [
                resourcePath.appendingPathComponent("lib").path,
                resourcePath.appendingPathComponent("Resource").appendingPathComponent("Init").path,
                resourcePath.appendingPathComponent("Resource").path,
                resourcePath.appendingPathComponent("fonts").path,
                resourcePath.appendingPathComponent("iccprofiles").path
            ].joined(separator: ":")
            process.environment = env
        }

        // Capture stdout and stderr
        let stderrPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = stdoutPipe

        var stderrOutput = ""

        // Handle stdout for progress parsing (Ghostscript outputs "Page N" to stdout)
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                if let progress = self?.parseProgress(from: output, totalPages: totalPages) {
                    DispatchQueue.main.async {
                        progressHandler(progress)
                    }
                }
            }
        }

        // Handle stderr for error capture
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                stderrOutput += output
            }
        }

        // Run process
        try process.run()
        process.waitUntilExit()

        // Clean up handlers
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        // Check exit status
        guard process.terminationStatus == 0 else {
            // Extract meaningful error from stderr
            let errorMessage = extractErrorMessage(from: stderrOutput)
            throw GhostscriptError.processFailed(
                exitCode: Int(process.terminationStatus),
                message: errorMessage
            )
        }

        // Verify output was created
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw GhostscriptError.outputWriteFailed
        }
    }

    /// Parse Ghostscript output for progress
    private func parseProgress(from output: String, totalPages: Int) -> GhostscriptProgress? {
        // Pattern: "Page N"
        let pagePattern = #"Page\s+(\d+)"#
        if let regex = try? NSRegularExpression(pattern: pagePattern),
           let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
           let pageRange = Range(match.range(at: 1), in: output),
           let page = Int(output[pageRange]) {
            let message: String
            if totalPages > 0 {
                let percent = (page * 100) / totalPages
                message = "Page \(page) of \(totalPages) (\(percent)%)"
            } else {
                message = "Processing page \(page)..."
            }
            return GhostscriptProgress(
                currentPage: page,
                totalPages: totalPages,
                message: message
            )
        }
        return nil
    }

    /// Extract error message from Ghostscript stderr
    private func extractErrorMessage(from stderr: String) -> String {
        let lines = stderr.components(separatedBy: .newlines)

        // Look for error lines
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().contains("error") ||
               trimmed.lowercased().contains("failed") ||
               trimmed.lowercased().contains("cannot") {
                return trimmed
            }
        }

        // Return last non-empty line as fallback
        return lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
    }
}
