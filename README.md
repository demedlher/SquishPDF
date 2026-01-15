# PDFConverter

A cross-platform PDF compression utility that reduces PDF file sizes while maintaining quality. Available for macOS and Windows.

## Features

- **Drag-and-drop** PDF file handling
- **Three compression levels** with different quality/size tradeoffs:
  - **Small** (72 DPI) - Lowest quality, smallest file size
  - **Medium** (150 DPI) - Balanced quality and size
  - **Large** (300 DPI) - Highest quality, larger file size
- Real-time progress indication during conversion
- Automatic file naming with DPI suffix (e.g., `document-150dpi.pdf`)
- Cross-platform support (macOS native + Windows)

## Screenshots

![PDFConverter UI](https://img.shields.io/badge/UI-Drag%20%26%20Drop-blue)

## Requirements

### macOS
- macOS 13.0 or later
- Swift 5.9 or later (for building from source)

### Windows
- Windows 10 (build 17763.0) or later
- .NET 7.0 Runtime

## Installation

### macOS

Download the latest DMG from the [Releases](https://github.com/demedlher/PDFConverter/releases) page, open it, and drag PDFConverter to your Applications folder.

Or build from source:

```bash
# Clone the repository
git clone https://github.com/demedlher/PDFConverter.git
cd PDFConverter

# Build and create app bundle
./build_app.sh
```

### Windows

Build from source using Visual Studio 2022 or the command line:

```bash
cd PDFConverter.Windows
dotnet build
dotnet run
```

## Usage

1. Launch PDFConverter
2. Drag and drop a PDF file onto the drop zone
3. Select your desired compression level (Small, Medium, or Large)
4. Click "Convert"
5. The compressed PDF will be saved in the same directory as the original with a DPI suffix

## Project Structure

```
PDFConverter/
├── Sources/PDFConverter/          # macOS Swift implementation
│   ├── PDFConverterApp.swift      # App entry point
│   ├── ContentView.swift          # Main UI
│   └── PDFConverterViewModel.swift # Conversion logic
├── PDFConverter.Windows/          # Windows C# implementation
│   ├── MainWindow.xaml            # UI layout
│   └── MainWindow.xaml.cs         # UI logic and PDF processing
├── Package.swift                  # Swift package manifest
├── build_app.sh                   # macOS app bundle builder
├── create_dmg.sh                  # DMG installer creator
└── create_icon.sh                 # App icon generator
```

## Tech Stack

### macOS
- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **PDF Processing**: PDFKit, CoreGraphics
- **Minimum OS**: macOS 13.0

### Windows
- **Language**: C# (.NET 7.0)
- **Framework**: WinUI 3 / Windows App SDK 1.4
- **PDF Processing**: PdfSharp 1.50.5147
- **Minimum OS**: Windows 10 (17763.0)

## How It Works

The converter renders each PDF page as a bitmap image at the specified DPI resolution, then rebuilds the PDF with these rendered images. This process reduces file size by:

- Downsampling high-resolution images
- Flattening complex vector graphics
- Applying compression to the resulting images

## Building from Source

### macOS

```bash
# Build release version
swift build -c release

# Run directly
swift run PDFConverter

# Build complete app bundle with DMG
./build_app.sh
```

### Windows

```bash
cd PDFConverter.Windows
dotnet restore
dotnet build -c Release
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

Demed ([@demedlher](https://github.com/demedlher))
