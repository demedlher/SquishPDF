# Native Compression Engine Design

**Date:** 2026-01-21
**Status:** Proposed
**Goal:** Replace Ghostscript with Apple-native frameworks for Mac App Store distribution

## Background

SquishPDF currently uses Ghostscript (AGPL licensed) for PDF compression. This prevents distribution through the Mac App Store, which requires:
- Sandboxed applications
- No AGPL/GPL dependencies
- No shelling out to external binaries

## Objectives

1. Create a compression engine using only Apple-native frameworks
2. Preserve text selectability (not rasterize entire pages)
3. Match Ghostscript compression ratios within ~20%
4. Enable Mac App Store distribution

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    SquishPDF Pro                        │
├─────────────────────────────────────────────────────────┤
│  CompressionEngine Protocol                             │
│  ├── GhostscriptEngine    - Existing (for comparison)   │
│  └── NativeEngine         - New implementation          │
│       ├── PDFImageExtractor                             │
│       ├── ImageDownsampler                              │
│       └── PDFRebuilder                                  │
├─────────────────────────────────────────────────────────┤
│  Shared: Presets, UI, Progress reporting                │
└─────────────────────────────────────────────────────────┘
```

### Key Design Decisions

1. **Separate branch** - Develop on `feature/native-compression`, keep `main` intact
2. **Protocol-based engine** - `CompressionEngine` protocol allows swapping GS/Native
3. **Same preset model** - Reuse existing DPI tiers (36, 72, 150, 300 DPI)
4. **Benchmark-first** - Validate approach before full implementation

### What Gets Preserved
- Text content (as PDF text objects)
- Vector graphics
- Document structure, bookmarks, links

### What Gets Reprocessed
- Raster images → downsampled to target DPI
- Image compression → re-encoded as JPEG at quality tier

## Image Extraction Strategy

Apple's PDFKit doesn't expose image objects directly. We use `CGPDFDocument` for low-level access.

### How PDF Images Work
- Images are stored as "XObject" resources with subtype "Image"
- Each page has a resource dictionary pointing to its images
- Images can be shared across pages (must track references)

### Extraction Approach

```swift
func extractImages(from page: CGPDFPage) -> [PDFImageRef] {
    // 1. Get page's resource dictionary
    let resources = page.dictionary["/Resources"]

    // 2. Get XObject subdictionary
    let xObjects = resources["/XObject"]

    // 3. Iterate and find images
    for (name, object) in xObjects {
        if object["/Subtype"] == "/Image" {
            // Extract: width, height, colorspace, bits, data stream
            // Track which pages reference this image
        }
    }
}
```

### Image Data Handling

| Source Format | Strategy |
|---------------|----------|
| Uncompressed | Extract raw, downsample, compress as JPEG |
| DCTDecode (JPEG) | Decompress, downsample, recompress |
| FlateDecode (PNG-like) | Decompress, downsample, compress as JPEG |
| JPEG2000, JBIG2 | Best-effort conversion |

### Output Format
- All recompressed images become JPEG (DCTDecode)
- Quality tiers mapped to presets:
  - Tiny: 30%
  - Small: 50%
  - Medium: 70%
  - Large: 85%
  - X-Large: 95%

### Known Limitations
- Exotic colorspaces (spot colors, separation) may need fallback handling

## PDF Rebuilding Strategy

Apple's frameworks are read-heavy, write-light. There's no "replace image in place" API.

### Approach: Hybrid Redraw

1. **Use PDFKit for structure** - Create new `PDFDocument`, copy metadata/outlines
2. **Use CGContext for pages** - Draw each page into a new PDF context
3. **Intercept image draws** - Hook into rendering to substitute downsampled images

```swift
func rebuildPDF(original: CGPDFDocument, processedImages: [String: CGImage]) -> Data {
    let context = CGContext(pdfDestination: output, mediaBox: pageRect)

    for pageIndex in 0..<pageCount {
        context.beginPDFPage()

        // Custom render that swaps images
        renderPage(original.page(at: pageIndex),
                   to: context,
                   imageReplacements: processedImages)

        context.endPDFPage()
    }
    return output
}
```

### The Key Technique

`CGPDFOperatorTable` lets us intercept PDF drawing operators. When we encounter the `Do` operator (draw XObject), we substitute our processed image instead of the original.

### What This Preserves
- Text as text (searchable, selectable)
- Vectors as vectors (scalable)
- Only raster images get replaced

## Benchmarking Strategy

Validate native approach against Ghostscript before committing to full implementation.

### Metrics

| Metric | What we measure | Success threshold |
|--------|-----------------|-------------------|
| Compression ratio | Output size / Input size | Within 20% of GS |
| Visual quality | SSIM or manual inspection | Acceptable at each DPI tier |
| Processing speed | Time per page | Within 2x of GS |
| Text integrity | Copy/paste from output | 100% preserved |

### Test Corpus

3-5 PDFs of varying types:
- Image-heavy (scanned docs, photos)
- Mixed (reports with charts + text)
- Text-heavy (minimal images)
- Large file (50+ pages)

### Benchmark Implementation

```swift
struct BenchmarkResult {
    let engine: String           // "ghostscript" or "native"
    let preset: String
    let inputSize: Int64
    let outputSize: Int64
    let compressionRatio: Double
    let durationSeconds: Double
    let peakMemoryMB: Double
}

func runBenchmark(file: URL, preset: Preset) -> [BenchmarkResult] {
    // Run both engines, collect metrics
    // Output as CSV or markdown table
}
```

### Phased Validation

1. **Phase 1:** Single image extraction/reinsertion works
2. **Phase 2:** Full page rebuild preserves text
3. **Phase 3:** Multi-page document, compare to GS
4. **Phase 4:** Full preset suite benchmark

## Project Structure

### New Files

```
Sources/SquishPDF/
├── Compression/
│   ├── CompressionEngine.swift      # Protocol for swappable engines
│   ├── GhostscriptEngine.swift      # Existing GS logic, refactored
│   └── NativeEngine/
│       ├── NativeCompressionEngine.swift   # Main entry point
│       ├── PDFImageExtractor.swift         # CGPDFDocument parsing
│       ├── ImageDownsampler.swift          # Core Image processing
│       └── PDFRebuilder.swift              # CGContext reconstruction
├── Benchmark/
│   ├── CompressionBenchmark.swift   # Runs both engines
│   └── BenchmarkResults.swift       # Data structures, reporting
└── (existing files unchanged)
```

### Protocol Design

```swift
protocol CompressionEngine {
    func compress(
        input: URL,
        output: URL,
        targetDPI: Int,
        quality: Double,
        progress: @escaping (Double) -> Void
    ) async throws

    var name: String { get }
    var isAvailable: Bool { get }
}
```

### UI Changes

- Benchmark mode: hidden debug menu or command-line flag
- No user-facing changes until native engine is validated

## Implementation Plan

### Phase 1: Foundation (Benchmark Infrastructure)
- [ ] Create `feature/native-compression` branch
- [ ] Define `CompressionEngine` protocol
- [ ] Refactor existing GS code into `GhostscriptEngine`
- [ ] Create benchmark harness with test corpus

### Phase 2: Image Extraction
- [ ] Implement `PDFImageExtractor` using CGPDFDocument
- [ ] Handle common image formats (JPEG, Flate, raw)
- [ ] Test extraction on various PDFs

### Phase 3: Image Processing
- [ ] Implement `ImageDownsampler` using Core Image
- [ ] Add JPEG quality tiers
- [ ] Validate visual quality at each preset

### Phase 4: PDF Rebuilding
- [ ] Implement `PDFRebuilder` with CGPDFOperatorTable
- [ ] Verify text/vector preservation
- [ ] Handle edge cases (shared images, rotated pages)

### Phase 5: Benchmark & Decision
- [ ] Run full benchmark suite
- [ ] Document results
- [ ] Go/no-go decision on native approach

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| CGPDFOperatorTable complexity | High | Start with simple PDFs, iterate |
| Compression ratio gap > 20% | High | May need to accept trade-off or explore alternatives |
| Exotic PDF features break | Medium | Fallback to "cannot compress" for unsupported files |
| Performance too slow | Medium | Profile and optimize; acceptable if < 2x GS |

## Decision Point

After Phase 5 benchmark:
- **If within 20% of GS:** Proceed with native engine for App Store version
- **If gap > 20%:** Reassess options (accept trade-off, explore page rasterization, or abandon App Store goal)
