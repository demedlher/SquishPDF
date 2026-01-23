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
