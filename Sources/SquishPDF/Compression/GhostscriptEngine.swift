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
