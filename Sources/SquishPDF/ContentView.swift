import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Design Constants

private enum UI {
    enum Color {
        static let textPrimary = SwiftUI.Color(NSColor.labelColor)
        static let textSecondary = SwiftUI.Color(NSColor.secondaryLabelColor)
        static let textTertiary = SwiftUI.Color(NSColor.tertiaryLabelColor)
        static let accent = SwiftUI.Color.accentColor
        static let success = SwiftUI.Color(red: 0.2, green: 0.78, blue: 0.35)
        static let background = SwiftUI.Color(NSColor.windowBackgroundColor)
        static let cardBackground = SwiftUI.Color(NSColor.controlBackgroundColor)
        static let selectionBackground = SwiftUI.Color.accentColor.opacity(0.06)
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 12
        static let md: CGFloat = 14
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 28
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
    }

    enum Font {
        static let caption: CGFloat = 12
        static let body: CGFloat = 14
        static let title: CGFloat = 15
        static let headline: CGFloat = 18
    }
}

// MARK: - PDF Icon View

struct PDFIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UI.Radius.sm)
                .fill(LinearGradient(
                    colors: [Color(red: 1, green: 0.42, blue: 0.42), Color(red: 0.93, green: 0.35, blue: 0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 44, height: 52)
                .shadow(color: Color(red: 0.93, green: 0.35, blue: 0.35).opacity(0.3), radius: 4, x: 0, y: 2)

            Text("PDF")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .tracking(0.3)
        }
    }
}

// MARK: - Preset Row View

struct PresetRowView: View {
    let preset: CompressionPreset
    let isSelected: Bool
    let isCheckbox: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: UI.Spacing.md) {
                // Radio or Checkbox
                ZStack {
                    if isCheckbox {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? UI.Color.accent : UI.Color.textTertiary, lineWidth: 2)
                            .frame(width: 18, height: 18)

                        if isSelected {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(UI.Color.accent)
                                .frame(width: 18, height: 18)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    } else {
                        Circle()
                            .stroke(isSelected ? UI.Color.accent : UI.Color.textTertiary, lineWidth: 2)
                            .frame(width: 18, height: 18)

                        if isSelected {
                            Circle()
                                .fill(UI.Color.accent)
                                .frame(width: 18, height: 18)
                            Circle()
                                .fill(.white)
                                .frame(width: 6, height: 6)
                        }
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.displayName)
                        .font(.system(size: UI.Font.body, weight: .medium))
                        .foregroundColor(UI.Color.textPrimary)
                    Text(preset.description)
                        .font(.system(size: UI.Font.caption))
                        .foregroundColor(UI.Color.textSecondary)
                }

                Spacer()

                // DPI Badge
                Text("\(preset.targetDPI) DPI")
                    .font(.system(size: UI.Font.caption, weight: .medium))
                    .foregroundColor(isSelected ? UI.Color.accent : UI.Color.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isSelected ? UI.Color.accent.opacity(0.1) : Color.black.opacity(0.04))
                    .cornerRadius(UI.Radius.sm)
            }
            .padding(.vertical, UI.Spacing.md)
            .padding(.horizontal, UI.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: UI.Radius.lg)
                .fill(UI.Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: UI.Radius.lg)
                .stroke(isSelected ? UI.Color.accent : Color.clear, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: UI.Radius.lg)
                .fill(isSelected ? UI.Color.selectionBackground : Color.clear)
        )
    }
}

// MARK: - Success Banner View

struct SuccessBannerView: View {
    let reductionPercent: Int
    let outputSize: String
    let onShow: () -> Void

    var body: some View {
        HStack(spacing: UI.Spacing.sm) {
            // Success icon
            ZStack {
                Circle()
                    .fill(UI.Color.success)
                    .frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text("\(reductionPercent)% smaller")
                    .font(.system(size: UI.Font.headline, weight: .semibold))
                    .foregroundColor(UI.Color.textPrimary)
                Text("\(outputSize) • Saved to original folder")
                    .font(.system(size: UI.Font.caption))
                    .foregroundColor(UI.Color.textSecondary)
            }

            Spacer()

            // Show button
            Button(action: onShow) {
                Text("Show")
                    .font(.system(size: UI.Font.caption, weight: .medium))
                    .foregroundColor(UI.Color.accent)
                    .padding(.horizontal, UI.Spacing.sm)
                    .padding(.vertical, UI.Spacing.xs)
            }
            .buttonStyle(.plain)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .padding(.vertical, UI.Spacing.md)
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var viewModel = SquishPDFViewModel()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: UI.Spacing.xxxl) {
                // File Zone
                fileZone

                // Mode Toggle + Presets
                VStack(spacing: UI.Spacing.xl) {
                    modeToggle
                    presetsSection
                }

                // Success or Error messages
                statusArea
            }

            Spacer()

            // Bottom section
            VStack(spacing: UI.Spacing.lg) {
                infoText
                compressButton
            }
        }
        .padding(UI.Spacing.xxl)
        .background(UI.Color.background)
    }

    // MARK: - File Zone

    private var fileZone: some View {
        Group {
            if viewModel.hasFile {
                fileCard
            } else {
                emptyDropZone
            }
        }
        .onDrop(of: [UTType.pdf], isTargeted: nil) { providers in
            viewModel.handleDroppedFiles(providers)
            return true
        }
    }

    private let dropZoneHeight: CGFloat = 84

    private var emptyDropZone: some View {
        VStack(spacing: UI.Spacing.sm) {
            Image(systemName: "doc.badge.arrow.up")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.7))

            Text("Drop PDF here")
                .font(.system(size: UI.Font.body))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .frame(height: dropZoneHeight)
        .background(
            RoundedRectangle(cornerRadius: UI.Radius.lg)
                .fill(Color(red: 0.55, green: 0.58, blue: 0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: UI.Radius.lg)
                .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
        )
    }

    private var fileCard: some View {
        HStack(spacing: UI.Spacing.md) {
            PDFIconView()

            VStack(alignment: .leading, spacing: UI.Spacing.xxs) {
                if viewModel.fileCount > 1 {
                    // Multiple files
                    Text("\(viewModel.fileCount) files selected")
                        .font(.system(size: UI.Font.body, weight: .medium))
                        .foregroundColor(UI.Color.textPrimary)

                    Text(SquishPDFViewModel.formatFileSize(viewModel.totalFileSize))
                        .font(.system(size: UI.Font.caption))
                        .foregroundColor(UI.Color.textSecondary)
                } else {
                    // Single file
                    Text(viewModel.originalFileName)
                        .font(.system(size: UI.Font.body, weight: .medium))
                        .foregroundColor(UI.Color.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: UI.Spacing.xs) {
                        Text(SquishPDFViewModel.formatFileSize(viewModel.originalFileSize))
                            .font(.system(size: UI.Font.caption))
                            .foregroundColor(UI.Color.textSecondary)

                        if let analysis = viewModel.pdfAnalysis, analysis.imageCount > 0 {
                            Circle()
                                .fill(UI.Color.textTertiary)
                                .frame(width: 3, height: 3)
                            Text("~\(analysis.avgDPI) DPI")
                                .font(.system(size: UI.Font.caption))
                                .foregroundColor(UI.Color.textSecondary)
                        }
                    }
                }
            }

            Spacer()

            Button(action: { viewModel.clearFile() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(UI.Color.textTertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.clear)
        }
        .padding(.horizontal, UI.Spacing.lg)
        .frame(maxWidth: .infinity)
        .frame(height: dropZoneHeight)
        .background(
            RoundedRectangle(cornerRadius: UI.Radius.lg)
                .fill(UI.Color.cardBackground)
                .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
        )
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack {
            Spacer()

            Picker("", selection: $viewModel.isBatchMode) {
                Text("Single file").tag(false)
                Text("Batch").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
        }
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: UI.Spacing.sm) {
            Text("STANDARD")
                .font(.system(size: UI.Font.caption, weight: .medium))
                .foregroundColor(UI.Color.textTertiary)
                .tracking(0.5)

            VStack(spacing: UI.Spacing.xs) {
                ForEach(CompressionPreset.standardPresets, id: \.id) { preset in
                    PresetRowView(
                        preset: preset,
                        isSelected: viewModel.isBatchMode
                            ? viewModel.isNativePresetSelected(preset)
                            : viewModel.selectedNativePreset == preset,
                        isCheckbox: viewModel.isBatchMode
                    ) {
                        if viewModel.isBatchMode {
                            viewModel.toggleNativePreset(preset)
                        } else {
                            viewModel.selectNativePreset(preset)
                        }
                    }
                }
            }

            // Specialized presets
            Text("SPECIALIZED")
                .font(.system(size: UI.Font.caption, weight: .medium))
                .foregroundColor(UI.Color.textTertiary)
                .tracking(0.5)
                .padding(.top, UI.Spacing.sm)

            VStack(spacing: UI.Spacing.xs) {
                ForEach(CompressionPreset.specializedPresets, id: \.id) { preset in
                    PresetRowView(
                        preset: preset,
                        isSelected: viewModel.isBatchMode
                            ? viewModel.isNativePresetSelected(preset)
                            : viewModel.selectedNativePreset == preset,
                        isCheckbox: viewModel.isBatchMode
                    ) {
                        if viewModel.isBatchMode {
                            viewModel.toggleNativePreset(preset)
                        } else {
                            viewModel.selectNativePreset(preset)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Status Area

    @ViewBuilder
    private var statusArea: some View {
        if let success = viewModel.conversionSuccess {
            // Parse the success message to extract percentage and size
            let (percent, size) = parseSuccessMessage(success)
            SuccessBannerView(
                reductionPercent: percent,
                outputSize: size,
                onShow: { viewModel.revealOutputInFinder() }
            )
        } else if let error = viewModel.lastError {
            HStack(spacing: UI.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(error)
                    .font(.system(size: UI.Font.caption))
                    .foregroundColor(.orange)
            }
            .padding(.vertical, UI.Spacing.sm)
        }
    }

    private func parseSuccessMessage(_ message: String) -> (Int, String) {
        // Parse "Saved: filename\n936 KB (95% smaller)" format
        let lines = message.components(separatedBy: "\n")
        if lines.count >= 2 {
            let sizeLine = lines[1]
            // Extract size (everything before the parenthesis)
            if let parenIndex = sizeLine.firstIndex(of: "(") {
                let sizeStr = String(sizeLine[..<parenIndex]).trimmingCharacters(in: .whitespaces)
                // Extract percentage
                if let percentRange = sizeLine.range(of: #"(\d+)%"#, options: .regularExpression) {
                    let percentStr = sizeLine[percentRange].dropLast()
                    return (Int(percentStr) ?? 0, sizeStr)
                }
            }
        }
        return (0, "")
    }

    // MARK: - Info Text

    private var infoText: some View {
        Text("Original file will not be modified")
            .font(.system(size: UI.Font.caption))
            .foregroundColor(UI.Color.textSecondary)
    }

    // MARK: - Compress Button

    private var compressButton: some View {
        Button(action: { viewModel.convert() }) {
            HStack(spacing: UI.Spacing.xs) {
                if viewModel.isConverting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                    if let message = viewModel.progressMessage {
                        Text(message)
                            .font(.system(size: UI.Font.title, weight: .semibold))
                    } else {
                        Text("Compressing...")
                            .font(.system(size: UI.Font.title, weight: .semibold))
                    }
                } else {
                    Text("Compress PDF")
                        .font(.system(size: UI.Font.title, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .foregroundColor(.white)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: UI.Radius.lg)
                .fill(
                    viewModel.hasFile && !viewModel.isConverting
                        ? LinearGradient(
                            colors: [Color(red: 0.23, green: 0.23, blue: 0.24), Color(red: 0.11, green: 0.11, blue: 0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                          )
                        : LinearGradient(
                            colors: [Color.secondary.opacity(0.3), Color.secondary.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                          )
                )
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
        )
        .disabled(!viewModel.hasFile || viewModel.isConverting)
    }
}
