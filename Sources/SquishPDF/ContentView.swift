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
            HStack(spacing: Design.Space.sm) {
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

                VStack(alignment: .leading, spacing: Design.Space.xxs) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.displayName)
                                .font(.system(size: Design.Font.body, weight: .medium))
                                .foregroundColor(.primary)
                            Text(preset.description)
                                .font(.system(size: Design.Font.caption))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !estimatedSize.isEmpty {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("est. new size:")
                                    .font(.system(size: Design.Font.caption))
                                    .foregroundColor(.secondary)
                                Text(estimatedSize)
                                    .font(.system(size: Design.Font.label))
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, Design.Space.xs)
            .padding(.horizontal, Design.Space.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: Design.Radius.md)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Design.Radius.md)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: Design.Font.body, weight: .semibold))
            .foregroundColor(Color(red: 0.25, green: 0.3, blue: 0.4))
    }
}

struct ContentView: View {
    @StateObject private var viewModel = SquishPDFViewModel()

    var body: some View {
        VStack(spacing: Design.Space.sm) {
            // Drop Zone / File Info
            dropZone

            Spacer().frame(height: Design.Space.xs)

            // Compression presets section
            VStack(alignment: .leading, spacing: Design.Space.sm) {
                HStack {
                    SectionHeader(title: "Compression presets")

                    Spacer()

                    // Badge
                    HStack(spacing: Design.Space.xxs) {
                        Image(systemName: "text.cursor")
                            .font(.system(size: Design.Font.caption))
                        Text("Text stays selectable")
                            .font(.system(size: Design.Font.caption))
                    }
                    .padding(.horizontal, Design.Space.xs)
                    .padding(.vertical, Design.Space.xxs)
                    .background(Color.secondary.opacity(0.12))
                    .foregroundColor(.secondary)
                    .cornerRadius(Design.Radius.sm)
                }

                // Standard presets
                VStack(spacing: Design.Space.xs) {
                    ForEach(GhostscriptPreset.standardPresets, id: \.self) { preset in
                        CompressionButton(
                            preset: preset,
                            isSelected: viewModel.selectedPreset == preset,
                            estimatedSize: viewModel.estimatedSizeString(for: preset)
                        ) {
                            viewModel.selectedPreset = preset
                        }
                    }
                }

                // Specialized presets section
                VStack(alignment: .leading, spacing: Design.Space.xs) {
                    Text("Specialized")
                        .font(.system(size: Design.Font.caption, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.top, Design.Space.xxs)

                    ForEach(GhostscriptPreset.specializedPresets, id: \.self) { preset in
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

            // Reassurance text
            Text("Convert with no fear. Your original PDF will not be modified. The converted file will be placed next to the original.")
                .font(.system(size: Design.Font.caption))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.bottom, Design.Space.xs)

            // Convert button at bottom
            Button(action: { viewModel.convert() }) {
                HStack(spacing: Design.Space.xs) {
                    if viewModel.isConverting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: Design.Icon.xs, height: Design.Icon.xs)
                        if let progress = viewModel.progress {
                            Text(progress.message)
                        } else {
                            Text("Converting...")
                        }
                    } else {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Convert")
                            .font(.system(size: Design.Font.body, weight: .medium))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: Design.Button.Height.lg)
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.md)
                    .fill(viewModel.hasFile && !viewModel.isConverting
                          ? Color(red: 0.2, green: 0.25, blue: 0.3)
                          : Color.secondary.opacity(0.3))
            )
            .disabled(!viewModel.hasFile || viewModel.isConverting)
        }
        .padding(Design.Space.md)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Design.Radius.lg)
                .fill(viewModel.hasFile
                      ? Color(NSColor.controlBackgroundColor)
                      : Color(red: 0.55, green: 0.58, blue: 0.62))
                .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)

            RoundedRectangle(cornerRadius: Design.Radius.lg)
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
        .frame(height: Design.Space.xxl + Design.Space.sm)  // 104 + 16 = 120
        .onDrop(of: [UTType.pdf], isTargeted: nil) { providers in
            viewModel.handleDroppedFiles(providers)
            return true
        }
    }

    private var emptyDropZone: some View {
        VStack(spacing: Design.Space.xs) {
            Image(systemName: "doc.badge.arrow.up")
                .font(.system(size: Design.Icon.lg))
                .foregroundColor(.white.opacity(0.7))

            Text("Drop your PDF here")
                .font(.system(size: Design.Font.body))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var fileInfoView: some View {
        HStack(spacing: Design.Space.sm) {
            Image(systemName: "doc.fill")
                .font(.system(size: Design.Icon.lg))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: Design.Space.xxs) {
                Text(viewModel.originalFileName)
                    .font(.system(size: Design.Font.body, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Original size: \(SquishPDFViewModel.formatFileSize(viewModel.originalFileSize))")
                    .font(.system(size: Design.Font.label))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { viewModel.clearFile() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: Design.Icon.sm))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Remove file")
        }
        .padding(.horizontal, Design.Space.md)
    }

    // MARK: - Status Messages

    @ViewBuilder
    private var statusMessages: some View {
        if let success = viewModel.conversionSuccess {
            HStack(spacing: Design.Space.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(success)
                    .font(.system(size: Design.Font.label))
            }
            .foregroundColor(.green)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }

        if let error = viewModel.lastError {
            HStack(spacing: Design.Space.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(error)
                    .font(.system(size: Design.Font.label))
            }
            .foregroundColor(.orange)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }

        if !viewModel.isGhostscriptAvailable {
            HStack(spacing: Design.Space.xxs) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Ghostscript not found. Install with: brew install ghostscript")
                    .font(.system(size: Design.Font.caption))
            }
            .foregroundColor(.orange)
            .padding(Design.Space.xs)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(Design.Radius.sm)
        }
    }
}
