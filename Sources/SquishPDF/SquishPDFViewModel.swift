import SwiftUI
import UniformTypeIdentifiers
import AppKit

class SquishPDFViewModel: ObservableObject {
    @Published var selectedPresets: Set<GhostscriptPreset> = [.ebook]
    @Published var isConverting = false
    @Published var lastError: String?
    @Published var progress: GhostscriptProgress?
    @Published var conversionSuccess: String?
    @Published var lastOutputURLs: [URL] = []

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

        // If we have PDF analysis, use multi-parameter range estimate
        if let analysis = pdfAnalysis {
            let stripsMetadata = (preset == .web)  // Web preset strips metadata
            let range = analysis.estimatedRatioRange(forTargetDPI: preset.dpi, stripsMetadata: stripsMetadata)

            let minSize = Int64(Double(originalFileSize) * range.low)
            let maxSize = Int64(Double(originalFileSize) * range.high)

            let minStr = Self.formatFileSize(minSize)
            let maxStr = Self.formatFileSize(maxSize)

            // If high estimate exceeds original, show "?" to indicate uncertainty
            if range.high >= 1.0 {
                return "\(minStr) - ?"
            }

            if minStr == maxStr {
                return "~\(minStr)"
            }
            return "\(minStr) - \(maxStr)"
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

    /// Compression effectiveness levels
    enum CompressionEffectiveness {
        case definite   // Green - significant compression expected
        case marginal   // Nothing - some improvement possible
        case unlikely   // Warning - little to no compression expected
    }

    /// Check how effective a preset will be based on PDF analysis
    func presetEffectiveness(_ preset: GhostscriptPreset) -> CompressionEffectiveness? {
        guard let analysis = pdfAnalysis, analysis.imageCount > 0 else {
            return nil  // No analysis available
        }

        // Grayscale uses source DPI, so effectiveness depends on color conversion
        if preset == .grayscale {
            return .marginal  // Grayscale conversion benefit is uncertain
        }

        let targetDPI = preset.dpi
        let sourceDPI = analysis.avgDPI

        // Calculate ratio of target to source
        let ratio = Double(targetDPI) / Double(sourceDPI)

        if ratio < 0.6 {
            return .definite   // Target is <60% of source - significant compression
        } else if ratio < 1.2 {
            return .marginal   // Target is 60-120% of source - some improvement possible
        } else {
            return .unlikely   // Target >120% of source - unlikely to help
        }
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
        lastOutputURLs = []
    }

    /// Toggle a preset selection
    func togglePreset(_ preset: GhostscriptPreset) {
        if selectedPresets.contains(preset) {
            // Don't allow deselecting if it's the only one selected
            if selectedPresets.count > 1 {
                selectedPresets.remove(preset)
            }
        } else {
            selectedPresets.insert(preset)
        }
    }

    /// Check if a preset is selected
    func isPresetSelected(_ preset: GhostscriptPreset) -> Bool {
        selectedPresets.contains(preset)
    }

    /// Reveal the output files in Finder
    func revealOutputInFinder() {
        guard !lastOutputURLs.isEmpty else { return }
        // Select all output files in Finder
        NSWorkspace.shared.activateFileViewerSelecting(lastOutputURLs)
    }

    /// Open the first output file
    func openOutputFile() {
        guard let url = lastOutputURLs.first else { return }
        NSWorkspace.shared.open(url)
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

        guard !selectedPresets.isEmpty else {
            lastError = "No presets selected"
            return
        }

        isConverting = true
        lastError = nil
        progress = nil
        conversionSuccess = nil
        lastOutputURLs = []

        // Get analysis data for conversion
        let sourceDPI = pdfAnalysis?.avgDPI
        let pageCount = pdfAnalysis?.pageCount ?? 0
        let originalFilename = url.deletingPathExtension().lastPathComponent
        let presetsToProcess = Array(selectedPresets).sorted { $0.dpi < $1.dpi }
        let totalPresets = presetsToProcess.count

        Task {
            var outputURLs: [URL] = []
            var results: [(filename: String, size: String, reduction: Int)] = []

            for (index, preset) in presetsToProcess.enumerated() {
                // Generate output filename with preset suffix
                let suffix = preset.filenameSuffix(withDPI: sourceDPI)
                let newFilename = "\(originalFilename)-\(suffix).pdf"
                let outputURL = url.deletingLastPathComponent().appendingPathComponent(newFilename)

                do {
                    try await ghostscriptService.compressPDF(
                        inputURL: url,
                        outputURL: outputURL,
                        preset: preset,
                        sourceDPI: sourceDPI,
                        pageCount: pageCount
                    ) { [weak self] progressInfo in
                        // Update progress with preset context
                        let updatedProgress: GhostscriptProgress
                        if totalPresets > 1 {
                            updatedProgress = GhostscriptProgress(
                                currentPage: progressInfo.currentPage,
                                totalPages: progressInfo.totalPages,
                                message: "[\(index + 1)/\(totalPresets)] \(preset.displayName): \(progressInfo.message)"
                            )
                        } else {
                            updatedProgress = progressInfo
                        }
                        Task { @MainActor in
                            self?.progress = updatedProgress
                        }
                    }

                    // Get compressed file size
                    let compressedSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64 ?? 0
                    let reduction = originalFileSize > 0 ? Int((1.0 - Double(compressedSize) / Double(originalFileSize)) * 100) : 0
                    let compressedSizeStr = Self.formatFileSize(compressedSize)

                    outputURLs.append(outputURL)
                    results.append((filename: newFilename, size: compressedSizeStr, reduction: reduction))

                } catch {
                    await MainActor.run {
                        self.lastError = "Failed on \(preset.displayName): \(error.localizedDescription)"
                        self.isConverting = false
                        self.progress = nil
                    }
                    return
                }
            }

            // Build success message
            let successMessage: String
            if results.count == 1 {
                let r = results[0]
                successMessage = "Saved: \(r.filename)\n\(r.size) (\(r.reduction)% smaller)"
            } else {
                let summary = results.map { "\($0.filename) – \($0.size) (\($0.reduction)%)" }.joined(separator: "\n")
                successMessage = "Saved \(results.count) files:\n\(summary)"
            }

            await MainActor.run {
                self.isConverting = false
                self.progress = nil
                self.lastOutputURLs = outputURLs
                self.conversionSuccess = successMessage
            }
        }
    }
}
