// Sources/SquishPDF/Compression/NativeEngine/PDFKitRebuilder.swift
import Foundation
import PDFKit
import CoreGraphics
import AppKit

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

            // IMPORTANT: Set the image size to original page bounds
            // This makes the image display at the original page size
            // while retaining the higher resolution pixels
            jpegImage.size = NSSize(width: bounds.width, height: bounds.height)

            // Create a PDF page from the properly-sized image
            guard let newPage = PDFPage(image: jpegImage) else { continue }

            newDocument.insert(newPage, at: pageIndex)
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
