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
        case .grayscale: return "Converts to grayscale, same quality"
        case .web: return "Web-optimized, stripped metadata (72 DPI)"
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
            // Convert to grayscale - DPI set dynamically via gsArguments(withDPI:)
            return [
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

    /// Get Ghostscript arguments with custom DPI (for grayscale which uses source DPI)
    func gsArguments(withDPI customDPI: Int?) -> [String] {
        if self == .grayscale, let dpi = customDPI {
            return [
                "-sColorConversionStrategy=Gray",
                "-dProcessColorModel=/DeviceGray",
                "-dColorImageResolution=\(dpi)",
                "-dGrayImageResolution=\(dpi)",
                "-dMonoImageResolution=\(dpi)",
                "-dDetectDuplicateImages=true",
                "-dRemoveUnusedResources=true"
            ]
        }
        return gsArguments
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
        case .grayscale: return "grayscale"  // DPI will be appended dynamically
        case .web: return "web-\(dpi)dpi"
        default: return "\(displayName.lowercased())-\(dpi)dpi"
        }
    }

    /// Get filename suffix with custom DPI (for grayscale which uses source DPI)
    func filenameSuffix(withDPI customDPI: Int?) -> String {
        if self == .grayscale, let dpi = customDPI {
            return "grayscale-\(dpi)dpi"
        }
        return filenameSuffix
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
    // Basic image info
    let imageCount: Int
    let avgDPI: Int
    let pageCount: Int                   // Total pages in PDF
    let pageWidthInches: Double
    let pageHeightInches: Double

    // Multi-parameter analysis
    let estimatedImageRatio: Double      // 0-1: portion of file that's image data
    let jpegCompressedRatio: Double      // 0-1: portion of images already JPEG compressed
    let hasCMYK: Bool                    // CMYK images present (4 channels)
    let hasMetadata: Bool                // XMP/metadata streams present
    let fontCount: Int                   // Number of embedded fonts

    /// Estimate compression ratio range for a given target DPI
    /// Returns (low, high) as percentages of original size
    func estimatedRatioRange(forTargetDPI targetDPI: Int, stripsMetadata: Bool = false) -> (low: Double, high: Double) {
        // Base case: no images or can't determine
        guard avgDPI > 0, imageCount > 0 else {
            return (0.4, 0.9)  // Wide range for unknown content
        }

        // 1. DPI-based compression factor
        let dpiRatio = Double(targetDPI) / Double(avgDPI)
        var baseCompression: Double

        if dpiRatio >= 1.0 {
            // Target DPI >= source: might increase size due to re-encoding
            baseCompression = 1.0
        } else {
            // DPI reduction: compression is roughly proportional to area reduction
            baseCompression = dpiRatio * dpiRatio
        }

        // 2. Adjust for existing JPEG compression
        // Already-compressed images have less room for improvement
        // Re-encoding JPEG can sometimes increase size
        let compressionPenalty = 1.0 + (jpegCompressedRatio * 0.3)  // Up to 30% penalty
        baseCompression *= compressionPenalty

        // 3. Weight by image ratio (text/vectors don't compress with DPI)
        let nonImageRatio = 1.0 - estimatedImageRatio
        let weightedCompression = (estimatedImageRatio * baseCompression) + (nonImageRatio * 0.95)

        // 4. Metadata savings (if stripping)
        let metadataSavings = (stripsMetadata && hasMetadata) ? 0.02 : 0.0

        // 5. Calculate range with uncertainty
        // More JPEG = more uncertainty (re-encoding is unpredictable)
        // Less image content = more uncertainty
        let uncertainty = 0.25 + (jpegCompressedRatio * 0.15) + ((1.0 - estimatedImageRatio) * 0.1)

        let midEstimate = weightedCompression - metadataSavings
        let low = max(0.05, midEstimate * (1.0 - uncertainty))
        let high = min(1.5, midEstimate * (1.0 + uncertainty))  // Can exceed 1.0 (file gets bigger)

        return (low, high)
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
        let fileSize = Double(data.count)

        // Get page count using PDFKit (runs in background, so OK here)
        let pageCount = getPageCount(for: url)

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
                let width = numbers[numbers.count - 2]
                let height = numbers[numbers.count - 1]
                pageWidthInches = width / 72.0
                pageHeightInches = height / 72.0
            }
        }

        // Track multi-parameter analysis
        var imageDPIs: [Int] = []
        var totalImagePixels: Int = 0
        var jpegImageCount = 0
        var hasCMYK = false
        var totalImageCount = 0

        // Check for metadata
        let hasMetadata = content.contains("/Metadata") || content.contains("/XMP")

        // Count fonts
        let fontMatches = content.components(separatedBy: "/Type /Font").count - 1
        let fontCount = max(0, fontMatches)

        // Pattern to find objects
        let objPattern = #"(\d+)\s+0\s+obj.*?endobj"#
        let regex = try? NSRegularExpression(pattern: objPattern, options: .dotMatchesLineSeparators)
        let nsContent = content as NSString

        regex?.enumerateMatches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length)) { match, _, _ in
            guard let match = match else { return }
            let objStr = nsContent.substring(with: match.range)

            // Check if this is an image object
            if objStr.contains("/Subtype") && objStr.contains("/Image") {
                totalImageCount += 1

                // Check compression type
                if objStr.contains("/DCTDecode") || objStr.contains("/JPXDecode") {
                    jpegImageCount += 1  // JPEG or JPEG2000 compressed
                }

                // Check color space
                if objStr.contains("/DeviceCMYK") || objStr.contains("/ICCBased") && objStr.contains("4") {
                    hasCMYK = true
                }

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

                // Calculate DPI if we have dimensions (filter out tiny images like icons)
                if let w = width, let h = height, w > 50, h > 50 {
                    totalImagePixels += w * h

                    let dpiFromWidth = Double(w) / pageWidthInches
                    let dpiFromHeight = Double(h) / pageHeightInches
                    let estimatedDPI = Int(max(dpiFromWidth, dpiFromHeight))

                    if estimatedDPI >= 10 && estimatedDPI <= 1200 {
                        imageDPIs.append(estimatedDPI)
                    }
                }
            }
        }

        // Calculate image ratio estimate
        // Rough estimate: 3 bytes per pixel for RGB, compressed ~10:1 for JPEG, ~2:1 for other
        let avgCompressionRatio = totalImageCount > 0 ? (Double(jpegImageCount) / Double(totalImageCount) * 10.0 + Double(totalImageCount - jpegImageCount) / Double(totalImageCount) * 2.0) : 5.0
        let estimatedUncompressedImageSize = Double(totalImagePixels) * 3.0
        let estimatedCompressedImageSize = estimatedUncompressedImageSize / avgCompressionRatio
        let estimatedImageRatio = min(0.95, estimatedCompressedImageSize / fileSize)

        // JPEG compression ratio
        let jpegCompressedRatio = totalImageCount > 0 ? Double(jpegImageCount) / Double(totalImageCount) : 0.0

        // Calculate DPI statistics
        let avgDPI = imageDPIs.isEmpty ? 0 : imageDPIs.reduce(0, +) / imageDPIs.count

        return PDFImageAnalysis(
            imageCount: totalImageCount,
            avgDPI: avgDPI,
            pageCount: pageCount,
            pageWidthInches: pageWidthInches,
            pageHeightInches: pageHeightInches,
            estimatedImageRatio: estimatedImageRatio,
            jpegCompressedRatio: jpegCompressedRatio,
            hasCMYK: hasCMYK,
            hasMetadata: hasMetadata,
            fontCount: fontCount
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
        sourceDPI: Int? = nil,  // Used for grayscale to maintain quality
        pageCount: Int = 0,     // Pre-computed page count for progress (avoids re-loading PDF)
        progressHandler: @escaping (GhostscriptProgress) -> Void
    ) async throws {
        guard let gsExecutable = gsPath else {
            throw GhostscriptError.notBundled
        }

        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw GhostscriptError.inputNotFound(inputURL)
        }

        let totalPages = pageCount

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
        // Add preset-specific arguments (with custom DPI for grayscale)
        arguments.append(contentsOf: preset.gsArguments(withDPI: sourceDPI))
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
