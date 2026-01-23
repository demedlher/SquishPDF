// Sources/SquishPDF/Compression/NativeEngine/PDFRebuilder.swift
import Foundation
import CoreGraphics
import PDFKit
import AppKit

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
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)  // Default letter size
        guard let pdfContext = CGContext(output as CFURL, mediaBox: &mediaBox, nil) else {
            throw CompressionError.outputWriteFailed(output)
        }

        for pageIndex in 1...pageCount {
            progress(pageIndex, pageCount)

            guard let page = source.page(at: pageIndex) else { continue }

            let pageMediaBox = page.getBoxRect(.mediaBox)

            // Begin new page with correct media box
            let pageInfo: [String: Any] = [
                kCGPDFContextMediaBox as String: NSValue(rect: pageMediaBox)
            ]
            pdfContext.beginPDFPage(pageInfo as CFDictionary)

            // Draw the page content
            // Note: Full operator interception for image substitution is complex in Swift.
            // For the initial implementation, we draw the page as-is.
            // The image replacement will need to be done via a different approach
            // (either using PDFKit or implementing a content stream parser).
            pdfContext.drawPDFPage(page)

            pdfContext.endPDFPage()
        }

        pdfContext.closePDF()
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
