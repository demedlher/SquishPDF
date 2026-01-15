import SwiftUI
import UniformTypeIdentifiers

struct CompressionButton: View {
    let preset: GhostscriptPreset
    let isSelected: Bool
    let estimatedSize: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Radio button
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                        .frame(width: 20, height: 20)

                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.displayName)
                                .font(.headline)
                            Text(preset.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !estimatedSize.isEmpty {
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("new size:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(estimatedSize)
                                    .font(.subheadline)
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ContentView: View {
    @StateObject private var viewModel = PDFConverterViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Drop Zone / File Info
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: viewModel.hasFile ? [] : [5]))
                    .foregroundColor(viewModel.hasFile ? .green : .blue.opacity(0.6))

                if viewModel.hasFile {
                    // Show file info
                    HStack(spacing: 16) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.originalFileName)
                                .font(.headline)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("Original size: \(PDFConverterViewModel.formatFileSize(viewModel.originalFileSize))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Clear button
                        Button(action: { viewModel.clearFile() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                } else {
                    // Show drop prompt
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.arrow.up")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)

                        Text("Drop your PDF here")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .onDrop(of: [UTType.pdf], isTargeted: nil) { providers in
                viewModel.handleDroppedFiles(providers)
                return true
            }

            Spacer().frame(height: 20)

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text("Compression preset")
                        .font(.headline)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "text.cursor")
                            .font(.caption)
                        Text("Text stays selectable")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(4)
                }

                // Preset options with estimated sizes
                VStack(spacing: 8) {
                    ForEach(GhostscriptPreset.allCases) { preset in
                        CompressionButton(
                            preset: preset,
                            isSelected: viewModel.selectedPreset == preset,
                            estimatedSize: viewModel.estimatedSizeString(for: preset)
                        ) {
                            viewModel.selectedPreset = preset
                        }
                    }
                }
            }

            Spacer().frame(height: 20)

            // Convert button
            Button(action: { viewModel.convert() }) {
                HStack {
                    if viewModel.isConverting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 20, height: 20)
                        if let progress = viewModel.progress {
                            Text(progress.message)
                        } else {
                            Text("Converting...")
                        }
                    } else {
                        Image(systemName: "arrow.down.doc")
                        Text("Convert")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasFile || viewModel.isConverting)

            // Success message
            if let success = viewModel.conversionSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(success)
                        .font(.callout)
                }
                .foregroundColor(.green)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }

            // Error display
            if let error = viewModel.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.callout)
                }
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }

            // Ghostscript availability warning
            if !viewModel.isGhostscriptAvailable {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Ghostscript not found. Install with: brew install ghostscript")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}
