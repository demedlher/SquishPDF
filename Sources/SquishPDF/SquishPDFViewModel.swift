import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Build Configuration
// Change this to switch between Native (App Store) and Ghostscript (GitHub) builds
enum CompressionBackend {
    case native      // For App Store - no external dependencies
    case ghostscript // For GitHub - AGPL license
}

let activeBackend: CompressionBackend = .native  // <- Change this for different builds

// MARK: - View Model

class SquishPDFViewModel: ObservableObject {
    // UI Mode
    @Published var isBatchMode = false

    // Ghostscript presets (for GS backend or batch mode reference)
    @Published var selectedGSPreset: GhostscriptPreset = .ebook
    @Published var selectedGSPresets: Set<GhostscriptPreset> = [.ebook]

    // Native presets
    @Published var selectedNativePreset: CompressionPreset = .medium
    @Published var selectedNativePresets: Set<String> = ["medium"]

    @Published var isConverting = false
    @Published var lastError: String?
    @Published var conversionSuccess: String?
    @Published var lastOutputURLs: [URL] = []

    // Progress
    @Published var progressMessage: String?
    @Published var progressPage: Int = 0
    @Published var progressTotal: Int = 0

    // File info
    @Published var droppedFileURLs: [URL] = []
    @Published var pdfAnalysis: PDFImageAnalysis?

    // Engines
    private let ghostscriptService = GhostscriptService()
    private let nativeEngine: NativeCompressionEngine = {
        let engine = NativeCompressionEngine()
        engine.useFallbackRebuilder = true
        return engine
    }()

    // MARK: - Computed Properties

    var isEngineAvailable: Bool {
        switch activeBackend {
        case .native: return nativeEngine.isAvailable
        case .ghostscript: return ghostscriptService.isAvailable()
        }
    }

    var engineName: String {
        switch activeBackend {
        case .native: return "Native"
        case .ghostscript: return "Ghostscript"
        }
    }

    var hasFile: Bool { !droppedFileURLs.isEmpty }
    var fileCount: Int { droppedFileURLs.count }
    var isSingleFile: Bool { droppedFileURLs.count == 1 }
    var firstFileURL: URL? { droppedFileURLs.first }
    var originalFileName: String { droppedFileURLs.first?.lastPathComponent ?? "" }

    var totalFileSize: Int64 {
        droppedFileURLs.reduce(0) { total, url in
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            return total + size
        }
    }

    var originalFileSize: Int64 {
        guard let url = droppedFileURLs.first else { return 0 }
        return (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    static func formatFileSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1_000
        let mb = kb / 1_000
        let gb = mb / 1_000

        if gb >= 1 { return "\(Int(round(gb))) GB" }
        else if mb >= 1 { return "\(Int(round(mb))) MB" }
        else { return "\(Int(round(kb))) KB" }
    }

    // MARK: - Ghostscript Helpers

    func estimatedSizeString(for preset: GhostscriptPreset) -> String {
        guard originalFileSize > 0 else { return "" }

        if let analysis = pdfAnalysis {
            let stripsMetadata = (preset == .web)
            let range = analysis.estimatedRatioRange(forTargetDPI: preset.dpi, stripsMetadata: stripsMetadata)
            let minSize = Int64(Double(originalFileSize) * range.low)
            let maxSize = Int64(Double(originalFileSize) * range.high)
            let minStr = Self.formatFileSize(minSize)
            let maxStr = Self.formatFileSize(maxSize)

            if range.high >= 1.0 { return "\(minStr) - ?" }
            if minStr == maxStr { return "~\(minStr)" }
            return "\(minStr) - \(maxStr)"
        }

        let range = preset.estimatedSizeRange(for: originalFileSize)
        let minStr = Self.formatFileSize(range.min)
        let maxStr = Self.formatFileSize(range.max)
        if minStr == maxStr { return minStr }
        return "\(minStr) - \(maxStr)"
    }

    enum CompressionEffectiveness { case definite, marginal, unlikely }

    func presetEffectiveness(_ preset: GhostscriptPreset) -> CompressionEffectiveness? {
        guard let analysis = pdfAnalysis, analysis.imageCount > 0 else { return nil }
        if preset == .grayscale { return .marginal }

        let ratio = Double(preset.dpi) / Double(analysis.avgDPI)
        if ratio < 0.6 { return .definite }
        else if ratio < 1.2 { return .marginal }
        else { return .unlikely }
    }

    // MARK: - File Handling

    func handleDroppedFiles(_ providers: [NSItemProvider]) {
        lastError = nil
        conversionSuccess = nil

        providers.forEach { provider in
            if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { [weak self] (urlData, error) in
                    if let error = error {
                        DispatchQueue.main.async { self?.lastError = error.localizedDescription }
                        return
                    }
                    guard let url = urlData as? URL else { return }
                    DispatchQueue.main.async { self?.addFile(url) }
                }
            }
        }
    }

    private func addFile(_ url: URL) {
        // In single mode, replace; in batch mode, add
        if !isBatchMode {
            droppedFileURLs = [url]
        } else {
            guard !droppedFileURLs.contains(url) else { return }
            droppedFileURLs.append(url)
        }

        if isSingleFile {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let analysis = self?.ghostscriptService.analyzePDF(at: url)
                DispatchQueue.main.async { self?.pdfAnalysis = analysis }
            }
        } else {
            pdfAnalysis = nil
        }
    }

    func clearFile() {
        droppedFileURLs = []
        pdfAnalysis = nil
        lastError = nil
        conversionSuccess = nil
        lastOutputURLs = []
    }

    func removeFile(at index: Int) {
        guard index >= 0 && index < droppedFileURLs.count else { return }
        droppedFileURLs.remove(at: index)

        if isSingleFile, let url = firstFileURL {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let analysis = self?.ghostscriptService.analyzePDF(at: url)
                DispatchQueue.main.async { self?.pdfAnalysis = analysis }
            }
        } else if droppedFileURLs.isEmpty {
            pdfAnalysis = nil
        }
    }

    // MARK: - Preset Selection (Single Mode)

    func selectGSPreset(_ preset: GhostscriptPreset) {
        selectedGSPreset = preset
    }

    func selectNativePreset(_ preset: CompressionPreset) {
        selectedNativePreset = preset
    }

    // MARK: - Preset Selection (Batch Mode)

    func toggleGSPreset(_ preset: GhostscriptPreset) {
        if selectedGSPresets.contains(preset) {
            if selectedGSPresets.count > 1 { selectedGSPresets.remove(preset) }
        } else {
            selectedGSPresets.insert(preset)
        }
    }

    func isGSPresetSelected(_ preset: GhostscriptPreset) -> Bool {
        selectedGSPresets.contains(preset)
    }

    func toggleNativePreset(_ preset: CompressionPreset) {
        if selectedNativePresets.contains(preset.id) {
            if selectedNativePresets.count > 1 { selectedNativePresets.remove(preset.id) }
        } else {
            selectedNativePresets.insert(preset.id)
        }
    }

    func isNativePresetSelected(_ preset: CompressionPreset) -> Bool {
        selectedNativePresets.contains(preset.id)
    }

    // MARK: - Output Actions

    func revealOutputInFinder() {
        guard !lastOutputURLs.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(lastOutputURLs)
    }

    func openOutputFile() {
        guard let url = lastOutputURLs.first else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Conversion

    func convert() {
        if isBatchMode {
            convertBatch()
        } else {
            convertSingle()
        }
    }

    private func convertSingle() {
        guard let fileURL = droppedFileURLs.first else {
            lastError = "No file selected"
            return
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            lastError = "PDF file not found"
            return
        }

        isConverting = true
        lastError = nil
        progressMessage = nil
        conversionSuccess = nil
        lastOutputURLs = []

        let originalFilename = fileURL.deletingPathExtension().lastPathComponent
        let fileSize = originalFileSize

        Task {
            do {
                let outputURL: URL

                switch activeBackend {
                case .native:
                    let preset = selectedNativePreset
                    let newFilename = "\(originalFilename)-\(preset.id)-\(preset.targetDPI)dpi.pdf"
                    outputURL = fileURL.deletingLastPathComponent().appendingPathComponent(newFilename)

                    try await nativeEngine.compress(input: fileURL, output: outputURL, preset: preset) { [weak self] progress in
                        Task { @MainActor in
                            self?.progressMessage = progress.message
                            self?.progressPage = progress.currentPage
                            self?.progressTotal = progress.totalPages
                        }
                    }

                case .ghostscript:
                    let preset = selectedGSPreset
                    let suffix = preset.filenameSuffix(withDPI: pdfAnalysis?.avgDPI)
                    let newFilename = "\(originalFilename)-\(suffix).pdf"
                    outputURL = fileURL.deletingLastPathComponent().appendingPathComponent(newFilename)

                    try await ghostscriptService.compressPDF(
                        inputURL: fileURL, outputURL: outputURL, preset: preset,
                        sourceDPI: pdfAnalysis?.avgDPI, pageCount: pdfAnalysis?.pageCount ?? 0
                    ) { [weak self] progress in
                        Task { @MainActor in
                            self?.progressMessage = progress.message
                            self?.progressPage = progress.currentPage
                            self?.progressTotal = progress.totalPages
                        }
                    }
                }

                let compressedSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
                let reduction = fileSize > 0 ? Int((1.0 - Double(compressedSize) / Double(fileSize)) * 100) : 0

                await MainActor.run {
                    self.isConverting = false
                    self.progressMessage = nil
                    self.lastOutputURLs = [outputURL]
                    self.conversionSuccess = "Saved: \(outputURL.lastPathComponent)\n\(Self.formatFileSize(compressedSize)) (\(reduction)% smaller)"
                }

            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.isConverting = false
                    self.progressMessage = nil
                }
            }
        }
    }

    private func convertBatch() {
        guard !droppedFileURLs.isEmpty else {
            lastError = "No files selected"
            return
        }

        for url in droppedFileURLs {
            guard FileManager.default.fileExists(atPath: url.path) else {
                lastError = "PDF file not found: \(url.lastPathComponent)"
                return
            }
        }

        isConverting = true
        lastError = nil
        progressMessage = nil
        conversionSuccess = nil
        lastOutputURLs = []

        let filesToProcess = droppedFileURLs
        let totalFiles = filesToProcess.count

        Task {
            var outputURLs: [URL] = []
            var results: [(filename: String, size: String, reduction: Int)] = []

            switch activeBackend {
            case .native:
                let presetsToProcess = CompressionPreset.all.filter { selectedNativePresets.contains($0.id) }
                    .sorted { $0.targetDPI < $1.targetDPI }
                let totalPresets = presetsToProcess.count

                for (fileIndex, fileURL) in filesToProcess.enumerated() {
                    let originalFilename = fileURL.deletingPathExtension().lastPathComponent
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0

                    for (presetIndex, preset) in presetsToProcess.enumerated() {
                        let newFilename = "\(originalFilename)-\(preset.id)-\(preset.targetDPI)dpi.pdf"
                        let outputURL = fileURL.deletingLastPathComponent().appendingPathComponent(newFilename)

                        do {
                            try await nativeEngine.compress(input: fileURL, output: outputURL, preset: preset) { [weak self] progress in
                                let msg = totalFiles > 1 || totalPresets > 1
                                    ? "[\(fileIndex+1)/\(totalFiles)] [\(presetIndex+1)/\(totalPresets)] \(progress.message)"
                                    : progress.message
                                Task { @MainActor in self?.progressMessage = msg }
                            }

                            let compressedSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
                            let reduction = fileSize > 0 ? Int((1.0 - Double(compressedSize) / Double(fileSize)) * 100) : 0
                            outputURLs.append(outputURL)
                            results.append((filename: newFilename, size: Self.formatFileSize(compressedSize), reduction: reduction))
                        } catch {
                            await MainActor.run {
                                self.lastError = "Failed: \(error.localizedDescription)"
                                self.isConverting = false
                            }
                            return
                        }
                    }
                }

            case .ghostscript:
                let presetsToProcess = Array(selectedGSPresets).sorted { $0.dpi < $1.dpi }
                let totalPresets = presetsToProcess.count

                for (fileIndex, fileURL) in filesToProcess.enumerated() {
                    let originalFilename = fileURL.deletingPathExtension().lastPathComponent
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0

                    for (presetIndex, preset) in presetsToProcess.enumerated() {
                        let suffix = preset.filenameSuffix(withDPI: nil)
                        let newFilename = "\(originalFilename)-\(suffix).pdf"
                        let outputURL = fileURL.deletingLastPathComponent().appendingPathComponent(newFilename)

                        do {
                            try await ghostscriptService.compressPDF(
                                inputURL: fileURL, outputURL: outputURL, preset: preset,
                                sourceDPI: nil, pageCount: 0
                            ) { [weak self] progress in
                                let msg = totalFiles > 1 || totalPresets > 1
                                    ? "[\(fileIndex+1)/\(totalFiles)] [\(presetIndex+1)/\(totalPresets)] \(progress.message)"
                                    : progress.message
                                Task { @MainActor in self?.progressMessage = msg }
                            }

                            let compressedSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
                            let reduction = fileSize > 0 ? Int((1.0 - Double(compressedSize) / Double(fileSize)) * 100) : 0
                            outputURLs.append(outputURL)
                            results.append((filename: newFilename, size: Self.formatFileSize(compressedSize), reduction: reduction))
                        } catch {
                            await MainActor.run {
                                self.lastError = "Failed: \(error.localizedDescription)"
                                self.isConverting = false
                            }
                            return
                        }
                    }
                }
            }

            let successMessage = results.count == 1
                ? "Saved: \(results[0].filename)\n\(results[0].size) (\(results[0].reduction)% smaller)"
                : "Saved \(results.count) files:\n" + results.map { "\($0.filename) – \($0.size) (\($0.reduction)%)" }.joined(separator: "\n")

            await MainActor.run {
                self.isConverting = false
                self.progressMessage = nil
                self.lastOutputURLs = outputURLs
                self.conversionSuccess = successMessage
            }
        }
    }
}
