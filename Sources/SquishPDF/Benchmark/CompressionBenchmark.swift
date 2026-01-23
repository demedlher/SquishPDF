// Sources/SquishPDF/Benchmark/CompressionBenchmark.swift
import Foundation

/// Results from a single benchmark run
struct BenchmarkResult {
    let engineName: String
    let presetId: String
    let inputFile: String
    let inputSize: Int64
    let outputSize: Int64
    let durationSeconds: Double
    let success: Bool
    let errorMessage: String?

    var compressionRatio: Double {
        guard inputSize > 0 else { return 0 }
        return Double(outputSize) / Double(inputSize)
    }

    var reductionPercent: Double {
        (1.0 - compressionRatio) * 100
    }
}

/// Benchmark runner for comparing compression engines
class CompressionBenchmark {
    private let engines: [CompressionEngine]
    private let presets: [CompressionPreset]
    private let tempDirectory: URL

    init(engines: [CompressionEngine], presets: [CompressionPreset] = CompressionPreset.all) {
        self.engines = engines
        self.presets = presets
        self.tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SquishPDF-Benchmark-\(UUID().uuidString)")
    }

    /// Run benchmark on a single file with all engines and presets
    func benchmark(file: URL) async -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []

        // Create temp directory
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let inputSize = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0

        for engine in engines {
            guard engine.isAvailable else {
                print("Skipping \(engine.name): not available")
                continue
            }

            for preset in presets {
                let outputFile = tempDirectory
                    .appendingPathComponent("\(engine.name)-\(preset.id).pdf")

                let startTime = Date()
                var success = true
                var errorMessage: String?

                do {
                    try await engine.compress(
                        input: file,
                        output: outputFile,
                        preset: preset,
                        progress: { _ in }  // Ignore progress for benchmark
                    )
                } catch {
                    success = false
                    errorMessage = error.localizedDescription
                }

                let duration = Date().timeIntervalSince(startTime)
                let outputSize = (try? FileManager.default.attributesOfItem(atPath: outputFile.path)[.size] as? Int64) ?? 0

                results.append(BenchmarkResult(
                    engineName: engine.name,
                    presetId: preset.id,
                    inputFile: file.lastPathComponent,
                    inputSize: inputSize,
                    outputSize: outputSize,
                    durationSeconds: duration,
                    success: success,
                    errorMessage: errorMessage
                ))

                // Clean up output file
                try? FileManager.default.removeItem(at: outputFile)
            }
        }

        return results
    }

    /// Format results as markdown table
    static func formatAsMarkdown(_ results: [BenchmarkResult]) -> String {
        var output = "| Engine | Preset | Input | Output | Reduction | Time | Status |\n"
        output += "|--------|--------|-------|--------|-----------|------|--------|\n"

        for r in results {
            let inputStr = formatBytes(r.inputSize)
            let outputStr = r.success ? formatBytes(r.outputSize) : "-"
            let reductionStr = r.success ? String(format: "%.1f%%", r.reductionPercent) : "-"
            let timeStr = String(format: "%.2fs", r.durationSeconds)
            let statusStr = r.success ? "OK" : "FAIL"

            output += "| \(r.engineName) | \(r.presetId) | \(inputStr) | \(outputStr) | \(reductionStr) | \(timeStr) | \(statusStr) |\n"
        }

        return output
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_000_000
        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        }
        let kb = Double(bytes) / 1_000
        return String(format: "%.0f KB", kb)
    }
}
