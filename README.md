# SquishPDF

Simple, no-frills, yet highly effective PDF compression for macOS. Drop the file, select the compression level, convert — done. No sprawling settings. No confusing menus. Just results.

## What's New in v2.9

- **Seven compression presets** - Including new Tiny, Grayscale, and Web options
- **Extreme compression** - Tiny preset achieves up to 98% file size reduction
- **Graphics-heavy PDF support** - Grayscale preset for documents where color isn't needed
- **Web optimization** - Stripped metadata, subset fonts, fast web view
- **Bundled Ghostscript** - Full installer works out of the box, no Homebrew required
- **Light & Dark mode** - Native macOS appearance support

| Light Mode | Dark Mode |
|:----------:|:---------:|
| ![Light Mode](screenshots/squishPDF-conversion-light-v2.9.png) | ![Dark Mode](screenshots/squishPDF-conversion-dark-v2.9.png) |

## Features

- **Drag-and-drop** PDF file handling
- **Seven compression presets** with different quality/size tradeoffs:
  - **Tiny** (36 DPI) - Extreme compression, maximum size reduction
  - **Small** (72 DPI) - Smallest file, for on-screen viewing
  - **Medium** (150 DPI) - Good quality for e-readers
  - **Large** (300 DPI) - High quality for printing
  - **X-Large** - Maximum quality for commercial print
  - **Grayscale** (150 DPI) - Converts to grayscale, great for graphics-heavy docs
  - **Web** (72 DPI) - Web-optimized with stripped metadata and subset fonts
- Text remains searchable and selectable after compression
- Estimated output size shown for each preset
- Automatic file naming with preset suffix (e.g., `document-medium-150dpi.pdf`)

## Who is this app for?

- **Office professionals** (marketing, sales, HR, finance) tired of emailing 50 MB PDFs
- **Anyone frustrated** with Preview's "Reduce File Size" producing barely-smaller files
- **Users who've tried** Adobe Acrobat, Office export options, or online compressors — and found them lacking
- **People who need** to meet upload size limits for portals, forms, or email attachments
- **Mac users who want** a native, offline solution that just works — no subscriptions, no uploads to sketchy websites

If you've ever wondered why your 80-page presentation is still 45 MB after "compressing" it, SquishPDF is for you.

## Requirements

### macOS
- macOS 13.0 or later
- Ghostscript (bundled in app, or install via `brew install ghostscript`)

## Installation

### macOS

Download from the [Releases](https://github.com/demedlher/SquishPDF/releases) page:

| Installer | Size | Description |
|-----------|------|-------------|
| `SquishPDF_Installer_Full.dmg` | ~22 MB | Includes Ghostscript — works out of the box |
| `SquishPDF_Installer_Lean.dmg` | ~3 MB | Requires `brew install ghostscript` first |

Open the DMG and drag SquishPDF to your Applications folder.

> **macOS Security Notice**: This app is not signed with an Apple Developer certificate, so macOS will quarantine it by default. If you trust this app, remove the quarantine attribute by running:
> ```bash
> xattr -cr /Applications/SquishPDF.app
> ```

Or build from source:

```bash
# Install Ghostscript (required for bundling)
brew install ghostscript

# Clone and build
git clone https://github.com/demedlher/SquishPDF.git
cd SquishPDF
./build_app.sh
```

## Usage

1. Launch SquishPDF
2. Drag and drop a PDF file onto the drop zone
3. Select your desired compression preset
4. Click Convert
5. The compressed PDF will be saved in the same directory with a preset suffix

## Compression Comparison

| Preset | Typical Reduction | Best For |
|--------|-------------------|----------|
| Tiny | 90-98% | Maximum compression, low quality acceptable |
| Small | 80-95% | Email attachments, web viewing |
| Medium | 60-80% | E-readers, tablets |
| Large | 30-60% | Office printing |
| X-Large | 5-30% | Professional printing |
| Grayscale | 70-90% | Graphics-heavy docs where color isn't needed |
| Web | 80-95% | Web publishing, fast loading |

## Project Structure

```
SquishPDF/
├── Sources/SquishPDF/             # macOS Swift implementation
│   ├── SquishPDFApp.swift         # App entry point
│   ├── ContentView.swift          # Main UI
│   ├── SquishPDFViewModel.swift   # Conversion orchestration
│   ├── GhostscriptService.swift   # Ghostscript wrapper
│   └── DesignTokens.swift         # UI design system
├── Package.swift                  # Swift package manifest
├── build_app.sh                   # macOS app bundle builder (--with-gs/--no-gs)
├── build_both.sh                  # Builds both Full and Lean installers
├── bundle_ghostscript.sh          # Ghostscript bundling script
├── create_dmg.sh                  # DMG installer creator
└── create_icon.sh                 # App icon generator
```

## Tech Stack

### macOS (v2.7)
- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **PDF Processing**: Ghostscript (bundled)
- **Minimum OS**: macOS 13.0

## How It Works

SquishPDF uses Ghostscript's PDF optimization engine which:
- Downsamples images to target DPI
- Compresses embedded fonts
- Removes unused objects
- Preserves text, vectors, and document structure

Unlike rasterization approaches, text remains fully selectable and searchable.

## Building from Source

### macOS

```bash
# Prerequisites
brew install ghostscript

# Build both installers (Full + Lean)
./build_both.sh

# Or build individually:
./build_app.sh --with-gs   # Full version with Ghostscript (~22 MB)
./build_app.sh --no-gs     # Lean version without Ghostscript (~3 MB)
```

## License

**AGPL-3.0** - see [LICENSE](LICENSE)

This application bundles Ghostscript, also licensed under AGPL-3.0.

## Author

Demed L'Her ([@demedlher](https://github.com/demedlher))
