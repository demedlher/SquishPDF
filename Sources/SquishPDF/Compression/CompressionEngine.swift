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

    // Specialized presets
    static let grayscale = CompressionPreset(
        id: "grayscale", displayName: "Grayscale", description: "Converts to grayscale, medium quality",
        targetDPI: 150, jpegQuality: 0.7, isGrayscale: true
    )
    static let web = CompressionPreset(
        id: "web", displayName: "Web", description: "Web-optimized, stripped metadata (72 DPI)",
        targetDPI: 72, jpegQuality: 0.6
    )

    /// Whether to convert to grayscale
    let isGrayscale: Bool

    init(id: String, displayName: String, description: String, targetDPI: Int, jpegQuality: Double, isGrayscale: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.targetDPI = targetDPI
        self.jpegQuality = jpegQuality
        self.isGrayscale = isGrayscale
    }

    /// Standard quality presets
    static let standardPresets: [CompressionPreset] = [.tiny, .small, .medium, .large]

    /// Specialized presets
    static let specializedPresets: [CompressionPreset] = [.grayscale, .web]

    /// All presets
    static let all: [CompressionPreset] = standardPresets + [.xlarge]
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
