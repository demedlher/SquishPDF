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

    // File info - supports multiple files
    @Published var droppedFileURLs: [URL] = []
    @Published var pdfAnalysis: PDFImageAnalysis?  // Only for single-file mode

    private let ghostscriptService = GhostscriptService()

    /// Check if Ghostscript is available
    var isGhostscriptAvailable: Bool {
        ghostscriptService.isAvailable()
    }

    /// Check if files are ready for conversion
    var hasFile: Bool {
        !droppedFileURLs.isEmpty
    }

    /// Number of files dropped
    var fileCount: Int {
        droppedFileURLs.count
    }

    /// Single file mode (enables detailed analysis)
    var isSingleFile: Bool {
        droppedFileURLs.count == 1
    }

    /// First file URL (for single-file mode)
    var firstFileURL: URL? {
        droppedFileURLs.first
    }

    /// First file name (for single-file display)
    var originalFileName: String {
        droppedFileURLs.first?.lastPathComponent ?? ""
    }

    /// Total size of all dropped files
    var totalFileSize: Int64 {
        droppedFileURLs.reduce(0) { total, url in
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            return total + size
        }
    }

    /// Size of first file (for single-file mode)
    var originalFileSize: Int64 {
        guard let url = droppedFileURLs.first else { return 0 }
        return (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
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
        // Clear previous state on new drop
        lastError = nil
        conversionSuccess = nil

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
                        self?.addFile(url)
                    }
                }
            }
        }
    }

    private func addFile(_ url: URL) {
        // Avoid duplicates
        guard !droppedFileURLs.contains(url) else { return }

        droppedFileURLs.append(url)

        // Only analyze if single file (for compression indicators)
        if isSingleFile {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let analysis = self?.ghostscriptService.analyzePDF(at: url)
                DispatchQueue.main.async {
                    self?.pdfAnalysis = analysis
                }
            }
        } else {
            // Clear analysis when multiple files
            pdfAnalysis = nil
        }
    }

    /// Clear all files
    func clearFile() {
        droppedFileURLs = []
        pdfAnalysis = nil
        lastError = nil
        conversionSuccess = nil
        lastOutputURLs = []
    }

    /// Remove a specific file by index
    func removeFile(at index: Int) {
        guard index >= 0 && index < droppedFileURLs.count else { return }
        droppedFileURLs.remove(at: index)

        // Re-analyze if back to single file
        if isSingleFile, let url = firstFileURL {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let analysis = self?.ghostscriptService.analyzePDF(at: url)
                DispatchQueue.main.async {
                    self?.pdfAnalysis = analysis
                }
            }
        } else if droppedFileURLs.isEmpty {
            pdfAnalysis = nil
        }
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
        guard !droppedFileURLs.isEmpty else {
            lastError = "No files selected"
            return
        }

        // Verify all files exist
        for url in droppedFileURLs {
            guard FileManager.default.fileExists(atPath: url.path) else {
                lastError = "PDF file not found: \(url.lastPathComponent)"
                return
            }
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

        let filesToProcess = droppedFileURLs
        let totalFiles = filesToProcess.count
        let presetsToProcess = Array(selectedPresets).sorted { $0.dpi < $1.dpi }
        let totalPresets = presetsToProcess.count

        // For single file, use analysis data
        let singleFileAnalysis = isSingleFile ? pdfAnalysis : nil

        Task {
            var outputURLs: [URL] = []
            var results: [(filename: String, size: String, reduction: Int)] = []

            // Option A: All presets per file, then next file
            for (fileIndex, fileURL) in filesToProcess.enumerated() {
                let originalFilename = fileURL.deletingPathExtension().lastPathComponent
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0

                // Use analysis for single file, nil for multi-file
                let sourceDPI = singleFileAnalysis?.avgDPI
                let pageCount = singleFileAnalysis?.pageCount ?? 0

                for (presetIndex, preset) in presetsToProcess.enumerated() {
                    // Generate output filename with preset suffix
                    let suffix = preset.filenameSuffix(withDPI: sourceDPI)
                    let newFilename = "\(originalFilename)-\(suffix).pdf"
                    let outputURL = fileURL.deletingLastPathComponent().appendingPathComponent(newFilename)

                    do {
                        try await ghostscriptService.compressPDF(
                            inputURL: fileURL,
                            outputURL: outputURL,
                            preset: preset,
                            sourceDPI: sourceDPI,
                            pageCount: pageCount
                        ) { [weak self] progressInfo in
                            // Update progress with file and preset context
                            let updatedProgress: GhostscriptProgress
                            let baseMessage = progressInfo.message

                            if totalFiles > 1 && totalPresets > 1 {
                                updatedProgress = GhostscriptProgress(
                                    currentPage: progressInfo.currentPage,
                                    totalPages: progressInfo.totalPages,
                                    message: "[File \(fileIndex + 1)/\(totalFiles)] [\(presetIndex + 1)/\(totalPresets)] \(baseMessage)"
                                )
                            } else if totalFiles > 1 {
                                updatedProgress = GhostscriptProgress(
                                    currentPage: progressInfo.currentPage,
                                    totalPages: progressInfo.totalPages,
                                    message: "[File \(fileIndex + 1)/\(totalFiles)] \(baseMessage)"
                                )
                            } else if totalPresets > 1 {
                                updatedProgress = GhostscriptProgress(
                                    currentPage: progressInfo.currentPage,
                                    totalPages: progressInfo.totalPages,
                                    message: "[\(presetIndex + 1)/\(totalPresets)] \(preset.displayName): \(baseMessage)"
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
                        let reduction = fileSize > 0 ? Int((1.0 - Double(compressedSize) / Double(fileSize)) * 100) : 0
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
