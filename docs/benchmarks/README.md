# Compression Engine Benchmarks

## Running Benchmarks

1. Build the app: `swift build`
2. Run the app: `.build/debug/SquishPDF`
3. Use **Cmd+Option+B** to open the benchmark dialog
4. Select one or more PDF files to benchmark
5. Results will be saved to `~/Desktop/benchmark-results.md`

## What Gets Tested

The benchmark runs all compression engines against all presets:

**Engines:**
- Ghostscript (existing implementation)
- Native (Apple) - new Core Graphics implementation

**Presets:**
| Preset | DPI | JPEG Quality |
|--------|-----|--------------|
| Tiny | 36 | 0.3 |
| Small | 72 | 0.5 |
| Medium | 150 | 0.7 |
| Large | 300 | 0.85 |
| X-Large | 300 | 0.95 |

## Output Format

Results are formatted as a markdown table:

| Engine | Preset | Input | Output | Reduction | Time | Status |
|--------|--------|-------|--------|-----------|------|--------|
| Ghostscript | tiny | 5.2 MB | 0.3 MB | 94.2% | 1.23s | OK |
| Native (Apple) | tiny | 5.2 MB | 0.4 MB | 92.3% | 0.89s | OK |
| ... | ... | ... | ... | ... | ... | ... |

## Current Status

The Native engine currently uses `PDFRebuilder` which draws pages as-is (no image replacement yet).
For reliable compression with the native engine, set `useFallbackRebuilder = true` in `NativeCompressionEngine.swift`
to use the PDFKit-based page rasterization approach.

## Success Criteria

| Metric | Target |
|--------|--------|
| Compression ratio | Within 20% of Ghostscript |
| Text selectability | 100% preserved (or accept fallback) |
| Processing speed | Within 2x of Ghostscript |
| Stability | No crashes on test corpus |
