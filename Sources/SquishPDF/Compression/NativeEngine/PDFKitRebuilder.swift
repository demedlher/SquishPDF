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
        grayscale: Bool = false,
        output: URL,
        progress: @escaping (Int, Int) -> Void
    ) throws {
        guard let document = PDFDocument(url: source) else {
            throw CompressionError.unsupportedPDF("Could not open PDF")
        }

        let pageCount = document.pageCount

        // Collect all page data first
        var pageDataArray: [(bounds: CGRect, jpegData: Data)] = []

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
            guard let image = renderPageToImage(page: page, size: CGSize(width: renderWidth, height: renderHeight), grayscale: grayscale) else {
                continue
            }

            // Compress as JPEG
            guard let jpegData = compressToJPEG(image: image, quality: jpegQuality) else {
                continue
            }

            pageDataArray.append((bounds: bounds, jpegData: jpegData))
        }

        // Create PDF using CGContext to ensure proper page sizing
        try createPDFFromJPEGPages(pageDataArray, output: output)
    }

    /// Create a PDF file from JPEG data with explicit page bounds
    private func createPDFFromJPEGPages(_ pages: [(bounds: CGRect, jpegData: Data)], output: URL) throws {
        // Create PDF context
        guard let pdfContext = CGContext(output as CFURL, mediaBox: nil, nil) else {
            throw CompressionError.outputWriteFailed(output)
        }

        for (bounds, jpegData) in pages {
            // Create image from JPEG data
            guard let dataProvider = CGDataProvider(data: jpegData as CFData),
                  let jpegImage = CGImage(jpegDataProviderSource: dataProvider,
                                          decode: nil,
                                          shouldInterpolate: true,
                                          intent: .defaultIntent) else {
                continue
            }

            // Begin page with original bounds
            var mediaBox = bounds
            pdfContext.beginPage(mediaBox: &mediaBox)

            // Draw JPEG image to fill the entire page bounds
            // The image will be scaled from its pixel dimensions to fill the page
            pdfContext.draw(jpegImage, in: bounds)

            pdfContext.endPage()
        }

        pdfContext.closePDF()
    }

    /// Render a PDF page to a CGImage
    private func renderPageToImage(page: PDFPage, size: CGSize, grayscale: Bool = false) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale = size.width / bounds.width

        let colorSpace: CGColorSpace
        let bitmapInfo: UInt32

        if grayscale {
            colorSpace = CGColorSpaceCreateDeviceGray()
            bitmapInfo = CGImageAlphaInfo.none.rawValue
        } else {
            colorSpace = CGColorSpaceCreateDeviceRGB()
            bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        }

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
        if grayscale {
            context.setFillColor(gray: 1.0, alpha: 1.0)
        } else {
            context.setFillColor(CGColor.white)
        }
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
