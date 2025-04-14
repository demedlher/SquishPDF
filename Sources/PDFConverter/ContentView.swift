import SwiftUI
import UniformTypeIdentifiers

struct CompressionButton: View {
    let title: String
    let description: String
    let dpi: Int
    let isSelected: Bool
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
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        VStack(spacing: 24) {
            // Drop Zone
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundColor(.blue.opacity(0.6))
                
                VStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("drag & drop your PDF here")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .onDrop(of: [UTType.pdf], isTargeted: nil) { providers in
                viewModel.handleDroppedFiles(providers)
                return true
            }
            
            VStack(alignment: .leading, spacing: 16) {
                // Compression Options
                Text("Compression level")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    CompressionButton(
                        title: "Small",
                        description: "Lower quality, smallest file size, 72 DPI",
                        dpi: 72,
                        isSelected: viewModel.selectedResolution.dpi == 72
                    ) {
                        viewModel.selectedResolution = .small
                    }
                    
                    CompressionButton(
                        title: "Medium",
                        description: "Balanced quality and file size, 150 DPI",
                        dpi: 150,
                        isSelected: viewModel.selectedResolution.dpi == 150
                    ) {
                        viewModel.selectedResolution = .medium
                    }
                    
                    CompressionButton(
                        title: "Large",
                        description: "Higher quality, larger file size, 300 DPI",
                        dpi: 300,
                        isSelected: viewModel.selectedResolution.dpi == 300
                    ) {
                        viewModel.selectedResolution = .large
                    }
                }
            }
            
            if viewModel.isConverting {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity)
            }
            
            if let error = viewModel.lastError {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
} 