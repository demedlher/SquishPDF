import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Compression Indicator

struct CompressionIndicator: View {
    let effectiveness: SquishPDFViewModel.CompressionEffectiveness?
    @State private var isHovering = false

    private let segmentWidth: CGFloat = 12
    private let segmentHeight: CGFloat = 6
    private let segmentSpacing: CGFloat = 2

    var body: some View {
        HStack(spacing: segmentSpacing) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(segment1Color)
                .frame(width: segmentWidth, height: segmentHeight)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(segment2Color)
                .frame(width: segmentWidth, height: segmentHeight)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(segment3Color)
                .frame(width: segmentWidth, height: segmentHeight)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
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
}

// MARK: - Ghostscript Preset Button (Radio - Single Mode)

struct GSPresetRadioButton: View {
    let preset: GhostscriptPreset
    let isSelected: Bool
    let effectiveness: SquishPDFViewModel.CompressionEffectiveness?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Space.sm) {
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.displayName)
                        .font(.system(size: Design.Font.body, weight: .medium))
                        .foregroundColor(.primary)
                    Text(preset.description)
                        .font(.system(size: Design.Font.caption))
                        .foregroundColor(.secondary)
                }

                Spacer()

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

// MARK: - Ghostscript Preset Button (Checkbox - Batch Mode)

struct GSPresetCheckboxButton: View {
    let preset: GhostscriptPreset
    let isSelected: Bool
    let effectiveness: SquishPDFViewModel.CompressionEffectiveness?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Space.sm) {
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.displayName)
                        .font(.system(size: Design.Font.body, weight: .medium))
                        .foregroundColor(.primary)
                    Text(preset.description)
                        .font(.system(size: Design.Font.caption))
                        .foregroundColor(.secondary)
                }

                Spacer()

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

// MARK: - Native Preset Button (Radio - Single Mode)

struct NativePresetRadioButton: View {
    let preset: CompressionPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Space.sm) {
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.displayName)
                        .font(.system(size: Design.Font.body, weight: .medium))
                        .foregroundColor(.primary)
                    Text(preset.description)
                        .font(.system(size: Design.Font.caption))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(preset.targetDPI) DPI")
                    .font(.system(size: Design.Font.caption, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
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

// MARK: - Native Preset Button (Checkbox - Batch Mode)

struct NativePresetCheckboxButton: View {
    let preset: CompressionPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Space.sm) {
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.displayName)
                        .font(.system(size: Design.Font.body, weight: .medium))
                        .foregroundColor(.primary)
                    Text(preset.description)
                        .font(.system(size: Design.Font.caption))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(preset.targetDPI) DPI")
                    .font(.system(size: Design.Font.caption, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
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

// MARK: - Section Header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: Design.Font.body, weight: .semibold))
            .foregroundColor(Color(red: 0.25, green: 0.3, blue: 0.4))
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var viewModel = SquishPDFViewModel()

    var body: some View {
        VStack(spacing: Design.Space.sm) {
            // Drop Zone
            dropZone

            Spacer().frame(height: Design.Space.xs)

            // Mode Toggle
            modeToggle

            // Compression presets section
            presetsSection

            // Status messages
            statusMessages

            Spacer()

            // Info text
            infoText

            // Convert button
            convertButton
        }
        .padding(Design.Space.md)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack {
            Toggle(isOn: $viewModel.isBatchMode) {
                HStack(spacing: Design.Space.xxs) {
                    Image(systemName: viewModel.isBatchMode ? "doc.on.doc" : "doc")
                        .font(.system(size: Design.Font.caption))
                    Text(viewModel.isBatchMode ? "Batch mode" : "Single file")
                        .font(.system(size: Design.Font.body, weight: .medium))
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Spacer()

            // Engine badge (informational)
            HStack(spacing: Design.Space.xxs) {
                Image(systemName: activeBackend == .native ? "apple.logo" : "terminal")
                    .font(.system(size: Design.Font.caption))
                Text(activeBackend == .native ? "Native" : "Ghostscript")
                    .font(.system(size: Design.Font.caption))
            }
            .padding(.horizontal, Design.Space.xs)
            .padding(.vertical, Design.Space.xxs)
            .background(activeBackend == .native ? Color.blue.opacity(0.12) : Color.green.opacity(0.12))
            .foregroundColor(activeBackend == .native ? .blue : .green)
            .cornerRadius(Design.Radius.sm)
        }
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: Design.Space.sm) {
            HStack {
                SectionHeader(title: "Compression presets")
                if viewModel.isBatchMode {
                    Text("(select multiple)")
                        .font(.system(size: Design.Font.caption))
                        .foregroundColor(.secondary)
                }
            }

            switch activeBackend {
            case .ghostscript:
                ghostscriptPresets
            case .native:
                nativePresets
            }
        }
    }

    private var ghostscriptPresets: some View {
        VStack(spacing: Design.Space.xs) {
            // Standard presets
            ForEach(GhostscriptPreset.standardPresets, id: \.self) { preset in
                if viewModel.isBatchMode {
                    GSPresetCheckboxButton(
                        preset: preset,
                        isSelected: viewModel.isGSPresetSelected(preset),
                        effectiveness: viewModel.presetEffectiveness(preset)
                    ) {
                        viewModel.toggleGSPreset(preset)
                    }
                } else {
                    GSPresetRadioButton(
                        preset: preset,
                        isSelected: viewModel.selectedGSPreset == preset,
                        effectiveness: viewModel.presetEffectiveness(preset)
                    ) {
                        viewModel.selectGSPreset(preset)
                    }
                }
            }

            // Specialized presets
            VStack(alignment: .leading, spacing: Design.Space.xs) {
                Text("Specialized")
                    .font(.system(size: Design.Font.caption, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.top, Design.Space.xxs)

                ForEach(GhostscriptPreset.specializedPresets, id: \.self) { preset in
                    if viewModel.isBatchMode {
                        GSPresetCheckboxButton(
                            preset: preset,
                            isSelected: viewModel.isGSPresetSelected(preset),
                            effectiveness: viewModel.presetEffectiveness(preset)
                        ) {
                            viewModel.toggleGSPreset(preset)
                        }
                    } else {
                        GSPresetRadioButton(
                            preset: preset,
                            isSelected: viewModel.selectedGSPreset == preset,
                            effectiveness: viewModel.presetEffectiveness(preset)
                        ) {
                            viewModel.selectGSPreset(preset)
                        }
                    }
                }
            }
        }
    }

    private var nativePresets: some View {
        VStack(spacing: Design.Space.xs) {
            ForEach(CompressionPreset.all, id: \.id) { preset in
                if viewModel.isBatchMode {
                    NativePresetCheckboxButton(
                        preset: preset,
                        isSelected: viewModel.isNativePresetSelected(preset)
                    ) {
                        viewModel.toggleNativePreset(preset)
                    }
                } else {
                    NativePresetRadioButton(
                        preset: preset,
                        isSelected: viewModel.selectedNativePreset == preset
                    ) {
                        viewModel.selectNativePreset(preset)
                    }
                }
            }
        }
    }

    // MARK: - Info Text

    private var infoText: some View {
        VStack(spacing: Design.Space.xs) {
            if activeBackend == .native {
                HStack(spacing: Design.Space.xxs) {
                    Image(systemName: "info.circle")
                        .font(.system(size: Design.Font.caption))
                    Text("Native mode: Pages are rasterized. Text will not be selectable.")
                        .font(.system(size: Design.Font.caption))
                }
                .foregroundColor(.orange)
                .padding(Design.Space.xs)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(Design.Radius.sm)
            }

            Text("Your original PDF will not be modified. The converted file will be placed next to the original.")
                .font(.system(size: Design.Font.caption))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Convert Button

    private var convertButton: some View {
        Button(action: { viewModel.convert() }) {
            HStack(spacing: Design.Space.xs) {
                if viewModel.isConverting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: Design.Icon.xs, height: Design.Icon.xs)
                    if let message = viewModel.progressMessage {
                        Text(message)
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
        .frame(height: Design.Space.xxl + Design.Space.sm)
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

    // MARK: - Status Messages

    @ViewBuilder
    private var statusMessages: some View {
        if let success = viewModel.conversionSuccess {
            HStack(spacing: Design.Space.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)

                Button(action: { viewModel.openOutputFile() }) {
                    Text(success)
                        .font(.system(size: Design.Font.label))
                        .underline()
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Click to open file")

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

        if !viewModel.isEngineAvailable {
            HStack(spacing: Design.Space.xxs) {
                Image(systemName: "exclamationmark.triangle.fill")
                if activeBackend == .ghostscript {
                    Text("Ghostscript not found. Install with: brew install ghostscript")
                        .font(.system(size: Design.Font.caption))
                } else {
                    Text("Compression engine unavailable")
                        .font(.system(size: Design.Font.caption))
                }
            }
            .foregroundColor(.orange)
            .padding(Design.Space.xs)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(Design.Radius.sm)
        }
    }
}
