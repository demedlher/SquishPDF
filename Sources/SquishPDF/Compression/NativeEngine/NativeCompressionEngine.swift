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
