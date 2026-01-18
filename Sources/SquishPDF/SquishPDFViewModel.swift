import SwiftUI
import UniformTypeIdentifiers

class SquishPDFViewModel: ObservableObject {
    @Published var selectedPreset: GhostscriptPreset = .ebook
    @Published var isConverting = false
    @Published var lastError: String?
    @Published var progress: GhostscriptProgress?
    @Published var conversionSuccess: String?

    // File info
    @Published var droppedFileURL: URL?
    @Published var originalFileSize: Int64 = 0
    @Published var originalFileName: String = ""
    @Published var pdfAnalysis: PDFImageAnalysis?

    private let ghostscriptService = GhostscriptService()

    /// Check if Ghostscript is available
    var isGhostscriptAvailable: Bool {
        ghostscriptService.isAvailable()
    }

    /// Check if a file is ready for conversion
    var hasFile: Bool {
        droppedFileURL != nil
    }

    /// Format file size for display (whole numbers only)
    static func formatFileSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1_000
        let mb = kb / 1_000
        let gb = mb / 1_000

        if gb >= 1 {
            return "\(Int(round(gb))) GB"
        } else if mb >= 1 {
            return "\(Int(round(mb))) MB"
        } else {
            return "\(Int(round(kb))) KB"
        }
    }

    /// Get estimated size range string for a preset
    func estimatedSizeString(for preset: GhostscriptPreset) -> String {
        guard originalFileSize > 0 else { return "" }

        // If we have PDF analysis, use it for smarter estimates
        if let analysis = pdfAnalysis, analysis.imageCount > 0 {
            let ratio = analysis.estimatedRatio(forTargetDPI: preset.dpi)
            let estimatedSize = Int64(Double(originalFileSize) * ratio)

            // Show single value for DPI-based estimate (more accurate)
            return Self.formatFileSize(estimatedSize)
        }

        // Fall back to generic range-based estimate
        let range = preset.estimatedSizeRange(for: originalFileSize)
        let minStr = Self.formatFileSize(range.min)
        let maxStr = Self.formatFileSize(range.max)
        if minStr == maxStr {
            return minStr
        }
        return "\(minStr) - \(maxStr)"
    }

    /// Check if a preset will be effective based on PDF analysis
    func isPresetEffective(_ preset: GhostscriptPreset) -> Bool {
        guard let analysis = pdfAnalysis, analysis.imageCount > 0 else {
            return true  // Assume effective if no analysis available
        }
        return analysis.isPresetEffective(preset)
    }

    func handleDroppedFiles(_ providers: [NSItemProvider]) {
        providers.forEach { provider in
            if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { [weak self] (urlData, error) in
                    if let error = error {
                        DispatchQueue.main.async {
                            self?.lastError = error.localizedDescription
                        }
                        return
                    }

                    guard let url = urlData as? URL else { return }

                    DispatchQueue.main.async {
                        self?.setFile(url)
                    }
                }
            }
        }
    }

    private func setFile(_ url: URL) {
        // Clear previous state
        lastError = nil
        conversionSuccess = nil

        // Store file info
        droppedFileURL = url
        originalFileName = url.lastPathComponent

        // Get file size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            originalFileSize = size
        } else {
            originalFileSize = 0
        }

        // Analyze PDF for smarter estimates (runs in background)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let analysis = self?.ghostscriptService.analyzePDF(at: url)
            DispatchQueue.main.async {
                self?.pdfAnalysis = analysis
            }
        }
    }

    /// Clear the current file
    func clearFile() {
        droppedFileURL = nil
        originalFileSize = 0
        originalFileName = ""
        pdfAnalysis = nil
        lastError = nil
        conversionSuccess = nil
    }

    /// Start conversion (called when user clicks Convert button)
    func convert() {
        guard let url = droppedFileURL else {
            lastError = "No file selected"
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            lastError = "PDF file not found"
            return
        }

        isConverting = true
        lastError = nil
        progress = nil
        conversionSuccess = nil

        // Generate output filename with preset suffix (e.g., doc-medium-150dpi.pdf)
        let originalFilename = url.deletingPathExtension().lastPathComponent
        let newFilename = "\(originalFilename)-\(selectedPreset.filenameSuffix).pdf"
        let outputURL = url.deletingLastPathComponent().appendingPathComponent(newFilename)

        Task {
            do {
                try await ghostscriptService.compressPDF(
                    inputURL: url,
                    outputURL: outputURL,
                    preset: selectedPreset
                ) { [weak self] progress in
                    self?.progress = progress
                }

                // Get compressed file size
                let compressedSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64 ?? 0

                // Calculate reduction percentage
                let reduction = originalFileSize > 0 ? Int((1.0 - Double(compressedSize) / Double(originalFileSize)) * 100) : 0
                let compressedSizeStr = Self.formatFileSize(compressedSize)

                await MainActor.run {
                    self.isConverting = false
                    self.progress = nil
                    self.conversionSuccess = "Saved: \(newFilename)\n\(compressedSizeStr) (\(reduction)% smaller)"
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.isConverting = false
                    self.progress = nil
                }
            }
        }
    }
}
