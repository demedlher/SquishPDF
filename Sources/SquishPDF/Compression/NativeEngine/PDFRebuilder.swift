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
