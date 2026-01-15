import SwiftUI
import UniformTypeIdentifiers
import AppKit

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
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 18, height: 18)

                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.displayName)
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                            Text(preset.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !estimatedSize.isEmpty {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("new size:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(estimatedSize)
                                    .font(.callout)
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(Color(red: 0.25, green: 0.3, blue: 0.4))
    }
}

struct ContentView: View {
    @StateObject private var viewModel = PDFConverterViewModel()

    var body: some View {
        VStack(spacing: 16) {
            // Drop Zone / File Info
            dropZone

            Spacer().frame(height: 8)

            // Compression presets section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Compression preset")

                    Spacer()

                    // Badge
                    HStack(spacing: 4) {
                        Image(systemName: "text.cursor")
                            .font(.caption2)
                        Text("Text stays selectable")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12))
                    .foregroundColor(.secondary)
                    .cornerRadius(4)
                }

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

            // Status messages
            statusMessages

            Spacer()

            // Convert button at bottom
            Button(action: { viewModel.convert() }) {
                HStack(spacing: 8) {
                    if viewModel.isConverting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                        if let progress = viewModel.progress {
                            Text(progress.message)
                        } else {
                            Text("Converting...")
                        }
                    } else {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Convert")
                            .font(.body.weight(.medium))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.hasFile && !viewModel.isConverting
                          ? Color(red: 0.2, green: 0.25, blue: 0.3)
                          : Color.secondary.opacity(0.3))
            )
            .disabled(!viewModel.hasFile || viewModel.isConverting)
        }
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(viewModel.hasFile
                      ? Color(NSColor.controlBackgroundColor)
                      : Color(red: 0.55, green: 0.58, blue: 0.62))
                .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)

            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    viewModel.hasFile ? Color.green.opacity(0.6) : Color.white.opacity(0.15),
                    style: StrokeStyle(lineWidth: 1.5, dash: viewModel.hasFile ? [] : [6])
                )

            if viewModel.hasFile {
                fileInfoView
            } else {
                emptyDropZone
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .onDrop(of: [UTType.pdf], isTargeted: nil) { providers in
            viewModel.handleDroppedFiles(providers)
            return true
        }
    }

    private var emptyDropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.badge.arrow.up")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.7))

            Text("Drop your PDF here")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var fileInfoView: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.originalFileName)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Original size: \(PDFConverterViewModel.formatFileSize(viewModel.originalFileSize))")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { viewModel.clearFile() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Remove file")
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Status Messages

    @ViewBuilder
    private var statusMessages: some View {
        if let success = viewModel.conversionSuccess {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(success)
                    .font(.callout)
            }
            .foregroundColor(.green)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }

        if let error = viewModel.lastError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(error)
                    .font(.callout)
            }
            .foregroundColor(.orange)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }

        if !viewModel.isGhostscriptAvailable {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Ghostscript not found. Install with: brew install ghostscript")
                    .font(.caption)
            }
            .foregroundColor(.orange)
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(6)
        }
    }
}
