import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import CoreGraphics

enum Resolution {
    case small
    case medium
    case large
    case custom(Int)
    
    var dpi: Int {
        switch self {
        case .small:
            return 72
        case .medium:
            return 150
        case .large:
            return 300
        case .custom(let value):
            return max(50, min(300, value))
        }
    }
}

class PDFConverterViewModel: ObservableObject {
    @Published var selectedResolution: Resolution = .medium
    @Published var isConverting = false
    @Published var lastError: String?
    
    func handleDroppedFiles(_ providers: [NSItemProvider]) {
        providers.forEach { provider in
            if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { (urlData, error) in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.lastError = error.localizedDescription
                        }
                        return
                    }
                    
                    guard let url = urlData as? URL else { return }
                    
                    DispatchQueue.main.async {
                        self.convertPDF(at: url)
                    }
                }
            }
        }
    }
    
    private func convertPDF(at url: URL) {
        guard let pdfDocument = PDFDocument(url: url) else {
            self.lastError = "Could not open PDF document"
            return
        }
        
        self.isConverting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let dpi = self.selectedResolution.dpi
            
            // Create new filename with DPI suffix
            let originalFilename = url.deletingPathExtension().lastPathComponent
            let newFilename = "\(originalFilename)-\(dpi)dpi.pdf"
            let newPath = url.deletingLastPathComponent().appendingPathComponent(newFilename)
            
            // Create new PDF with modified resolution
            if let data = self.createPDFData(from: pdfDocument, withDPI: dpi) {
                do {
                    try data.write(to: newPath)
                    DispatchQueue.main.async {
                        self.isConverting = false
                        self.lastError = nil
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.lastError = "Failed to save converted PDF: \(error.localizedDescription)"
                        self.isConverting = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.lastError = "Failed to create converted PDF"
                    self.isConverting = false
                }
            }
        }
    }
    
    private func createPDFData(from document: PDFDocument, withDPI dpi: Int) -> Data? {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData) else { return nil }
        
        // Create PDF context
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: nil, nil) else { return nil }
        
        // Process each page
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageBounds = page.bounds(for: .mediaBox)
            
            // Calculate dimensions for the new resolution
            let scale = CGFloat(dpi) / 72.0
            let width = Int(ceil(pageBounds.width * scale))
            let height = Int(ceil(pageBounds.height * scale))
            
            // Create bitmap context for rendering
            guard let bitmapContext = CGContext(data: nil,
                                              width: width,
                                              height: height,
                                              bitsPerComponent: 8,
                                              bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { continue }
            
            // Set white background
            bitmapContext.setFillColor(CGColor.white)
            bitmapContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            // Scale and render the page
            bitmapContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: bitmapContext)
            
            // Get the rendered image
            guard let renderedImage = bitmapContext.makeImage() else { continue }
            
            // Create a new PDF page with proper dimensions
            var mediaBox = CGRect(x: 0, y: 0, width: CGFloat(width) / scale, height: CGFloat(height) / scale)
            pdfContext.beginPage(mediaBox: &mediaBox)
            
            // Draw the rendered image
            pdfContext.draw(renderedImage, in: mediaBox)
            pdfContext.endPage()
        }
        
        pdfContext.closePDF()
        return pdfData as Data
    }
} 