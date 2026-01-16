import Foundation

/// Ghostscript compression presets matching -dPDFSETTINGS parameter
enum GhostscriptPreset: String, CaseIterable, Identifiable {
    case screen = "screen"
    case ebook = "ebook"
    case printer = "printer"
    case prepress = "prepress"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .screen: return "Small"
        case .ebook: return "Medium"
        case .printer: return "Large"
        case .prepress: return "X-Large"
        }
    }

    var description: String {
        switch self {
        case .screen: return "Lowest quality, smallest file (72 DPI)"
        case .ebook: return "Good quality for e-readers (150 DPI)"
        case .printer: return "High quality for printing (300 DPI)"
        case .prepress: return "Maximum quality, commercial print"
        }
    }

    var gsParameter: String {
        "/\(rawValue)"
    }

    /// DPI value for this preset
    var dpi: Int {
        switch self {
        case .screen: return 72
        case .ebook: return 150
        case .printer: return 300
        case .prepress: return 300
        }
    }

    /// Filename suffix (e.g., "medium-150dpi")
    var filenameSuffix: String {
        "\(displayName.lowercased())-\(dpi)dpi"
    }

    /// Estimated compression ratio range (min, max) as percentage of original size
    var estimatedRatioRange: (min: Double, max: Double) {
        switch self {
        case .screen: return (0.05, 0.20)   // 5-20% of original (80-95% reduction)
        case .ebook: return (0.20, 0.40)    // 20-40% of original (60-80% reduction)
        case .printer: return (0.40, 0.70)  // 40-70% of original (30-60% reduction)
        case .prepress: return (0.70, 0.95) // 70-95% of original (5-30% reduction)
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
    let message: String
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

        let process = Process()
        process.executableURL = gsExecutable

        // Build Ghostscript arguments
        process.arguments = [
            "-dNOPAUSE",
            "-dBATCH",
            "-dSAFER",
            "-sDEVICE=pdfwrite",
            "-dCompatibilityLevel=1.4",
            "-dPDFSETTINGS=\(preset.gsParameter)",
            "-sOutputFile=\(outputURL.path)",
            inputURL.path
        ]

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

        // Capture stderr for progress and errors
        let stderrPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = stdoutPipe

        var stderrOutput = ""

        // Handle stderr for progress parsing
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                stderrOutput += output
                if let progress = self?.parseProgress(from: output) {
                    DispatchQueue.main.async {
                        progressHandler(progress)
                    }
                }
            }
        }

        // Run process
        try process.run()
        process.waitUntilExit()

        // Clean up handler
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
    private func parseProgress(from output: String) -> GhostscriptProgress? {
        // Pattern: "Page N"
        let pagePattern = #"Page\s+(\d+)"#
        if let regex = try? NSRegularExpression(pattern: pagePattern),
           let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
           let pageRange = Range(match.range(at: 1), in: output),
           let page = Int(output[pageRange]) {
            return GhostscriptProgress(
                currentPage: page,
                message: "Processing page \(page)..."
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
