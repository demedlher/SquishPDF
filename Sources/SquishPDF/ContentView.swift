import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// 3-segment compression potential indicator
struct CompressionIndicator: View {
    let effectiveness: SquishPDFViewModel.CompressionEffectiveness?
    @State private var isHovering = false

    private let segmentWidth: CGFloat = 12
    private let segmentHeight: CGFloat = 6
    private let segmentSpacing: CGFloat = 2

    var body: some View {
        HStack(spacing: segmentSpacing) {
            // Segment 1 (left) - always shows state
            RoundedRectangle(cornerRadius: 1.5)
                .fill(segment1Color)
                .frame(width: segmentWidth, height: segmentHeight)

            // Segment 2 (middle)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(segment2Color)
                .frame(width: segmentWidth, height: segmentHeight)

            // Segment 3 (right)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(segment3Color)
                .frame(width: segmentWidth, height: segmentHeight)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .overlay(alignment: .bottomTrailing) {
            if isHovering {
                Text(helpText)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                    .fixedSize()
                    .offset(x: 0, y: -20)
            }
        }
    }

    private var segment1Color: Color {
        guard let eff = effectiveness else { return Color.secondary.opacity(0.3) }
        switch eff {
        case .unlikely: return Color.red.opacity(0.7)
        case .marginal: return Color.orange.opacity(0.7)
        case .definite: return Color.green.opacity(0.7)
        }
    }

    private var segment2Color: Color {
        guard let eff = effectiveness else { return Color.secondary.opacity(0.3) }
        switch eff {
        case .unlikely: return Color.secondary.opacity(0.3)
        case .marginal: return Color.orange.opacity(0.7)
        case .definite: return Color.green.opacity(0.7)
        }
    }

    private var segment3Color: Color {
        guard let eff = effectiveness else { return Color.secondary.opacity(0.3) }
        switch eff {
        case .unlikely: return Color.secondary.opacity(0.3)
        case .marginal: return Color.secondary.opacity(0.3)
        case .definite: return Color.green.opacity(0.7)
        }
    }

    private var helpText: String {
        guard let eff = effectiveness else { return "Drop a PDF to see compression potential" }
        switch eff {
        case .unlikely: return "Unlikely to compress"
        case .marginal: return "Might compress some"
        case .definite: return "Will compress"
        }
    }
}

struct CompressionButton: View {
    let preset: GhostscriptPreset
    let isSelected: Bool
    let effectiveness: SquishPDFViewModel.CompressionEffectiveness?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Space.sm) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 18, height: 18)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor)
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Preset info
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.displayName)
                        .font(.system(size: Design.Font.body, weight: .medium))
                        .foregroundColor(.primary)
                    Text(preset.description)
                        .font(.system(size: Design.Font.caption))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Compression potential indicator
                CompressionIndicator(effectiveness: effectiveness)
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
                            isSelected: viewModel.isPresetSelected(preset),
                            effectiveness: viewModel.presetEffectiveness(preset)
                        ) {
                            viewModel.togglePreset(preset)
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
                            isSelected: viewModel.isPresetSelected(preset),
                            effectiveness: viewModel.presetEffectiveness(preset)
                        ) {
                            viewModel.togglePreset(preset)
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.md)
                    .fill(viewModel.hasFile && !viewModel.isConverting
                          ? Color(red: 0.2, green: 0.25, blue: 0.3)
                          : Color.secondary.opacity(0.3))
            )
            .contentShape(Rectangle())
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
                    viewModel.hasFile ? Color(red: 0.2, green: 0.25, blue: 0.3).opacity(0.6) : Color.white.opacity(0.15),
                    style: StrokeStyle(lineWidth: 1.5, dash: viewModel.hasFile ? [] : [6])
                )

            if viewModel.hasFile {
                if viewModel.isSingleFile {
                    singleFileInfoView
                } else {
                    multiFileInfoView
                }
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

            Text("Drop your PDFs here")
                .font(.system(size: Design.Font.body))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var singleFileInfoView: some View {
        HStack(spacing: Design.Space.sm) {
            Image(systemName: "doc.fill")
                .font(.system(size: Design.Icon.lg))
                .foregroundColor(Color(red: 0.2, green: 0.25, blue: 0.3))

            VStack(alignment: .leading, spacing: Design.Space.xxs) {
                Text(viewModel.originalFileName)
                    .font(.system(size: Design.Font.body, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Original size: \(SquishPDFViewModel.formatFileSize(viewModel.originalFileSize))")
                    .font(.system(size: Design.Font.caption))
                    .foregroundColor(.secondary)
                if let analysis = viewModel.pdfAnalysis, analysis.imageCount > 0 {
                    Text("Est. image quality: ~\(analysis.avgDPI) DPI")
                        .font(.system(size: Design.Font.caption))
                        .foregroundColor(.secondary)
                    Text(qualityDescription(for: analysis.avgDPI))
                        .font(.system(size: Design.Font.caption))
                        .foregroundColor(qualityColor(for: analysis.avgDPI))
                }
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

    private var multiFileInfoView: some View {
        HStack(spacing: Design.Space.sm) {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: Design.Icon.lg))
                .foregroundColor(Color(red: 0.2, green: 0.25, blue: 0.3))

            VStack(alignment: .leading, spacing: Design.Space.xxs) {
                Text("\(viewModel.fileCount) files selected")
                    .font(.system(size: Design.Font.body, weight: .medium))
                    .foregroundColor(.primary)
                Text("Total size: \(SquishPDFViewModel.formatFileSize(viewModel.totalFileSize))")
                    .font(.system(size: Design.Font.caption))
                    .foregroundColor(.secondary)
                // Show first few filenames
                Text(fileListSummary)
                    .font(.system(size: Design.Font.caption))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: { viewModel.clearFile() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: Design.Icon.sm))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Remove all files")
        }
        .padding(.horizontal, Design.Space.md)
    }

    private var fileListSummary: String {
        let names = viewModel.droppedFileURLs.map { $0.lastPathComponent }
        if names.count <= 3 {
            return names.joined(separator: ", ")
        } else {
            let first3 = names.prefix(3).joined(separator: ", ")
            return "\(first3), +\(names.count - 3) more"
        }
    }

    // MARK: - Quality Description Helpers

    private func qualityDescription(for dpi: Int) -> String {
        switch dpi {
        case 300...:
            return "High quality source – likely to compress well"
        case 150..<300:
            return "Good quality source – should compress"
        case 72..<150:
            return "Medium quality source – may compress some more"
        default:
            return "Low quality source – unlikely to compress more"
        }
    }

    private func qualityColor(for dpi: Int) -> Color {
        switch dpi {
        case 300...:
            return .green
        case 150..<300:
            return .green.opacity(0.8)
        case 72..<150:
            return .orange
        default:
            return .red.opacity(0.8)
        }
    }

    // MARK: - Status Messages

    @ViewBuilder
    private var statusMessages: some View {
        if let success = viewModel.conversionSuccess {
            HStack(spacing: Design.Space.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)

                // Filename - click to open
                Button(action: { viewModel.openOutputFile() }) {
                    Text(success)
                        .font(.system(size: Design.Font.label))
                        .underline()
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Click to open file")

                // Folder icon - click to reveal in Finder
                Button(action: { viewModel.revealOutputInFinder() }) {
                    Image(systemName: "folder")
                        .font(.system(size: Design.Font.label))
                        .foregroundColor(.green.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
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
