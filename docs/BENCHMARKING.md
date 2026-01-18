# SquishPDF Performance Benchmarking

This document describes how to track and compare SquishPDF compression performance across releases.

## Overview

Performance is tracked using:
- **Sample PDFs**: A consistent set of test documents in `sample-docs/`
- **Benchmark script**: `benchmark.sh` runs all presets on all samples
- **Results CSV**: `docs/performance-history.csv` stores historical data

## Quick Start

```bash
# Run benchmark before a release
./benchmark.sh v2.10

# View results
cat docs/performance-history.csv | column -t -s,
```

## Sample Documents

The following original PDFs are used for benchmarking (keep these consistent across releases):

| File | Size | Type | Description |
|------|------|------|-------------|
| `2025-05-08-Writer.AI+DR.pdf` | 11 MB | Mixed | Document with text and images |
| `AI-visibility-index.pdf` | 51 MB | Graphics-heavy | Large report with many images |
| `brochure-sweden-english.pdf` | 20 MB | Marketing | Brochure with photos |
| `DR-brandbook.pdf` | 24 MB | Design | Brand guidelines with images |

**Important**:
- Only original files (without preset suffixes like `-small-72dpi`) are benchmarked
- Keep the same sample files across releases for valid comparisons
- Large files (>20MB) may take several minutes per preset

## Running Benchmarks

### Before a Release

```bash
# Build the app first (to use bundled Ghostscript)
./build_app.sh --with-gs

# Run benchmark with release tag
./benchmark.sh v2.11
```

### During Development

```bash
# Run benchmark (uses "dev" as release tag)
./benchmark.sh

# Or with a descriptive tag
./benchmark.sh feature-xyz-test
```

### What Gets Tested

Each sample PDF is compressed with all 7 presets:
- `tiny` (36 DPI)
- `small` (72 DPI)
- `medium` (150 DPI)
- `large` (300 DPI)
- `xlarge` (prepress quality)
- `grayscale` (source DPI, grayscale conversion)
- `web` (72 DPI, web-optimized)

## Results Format

Results are stored in `docs/performance-history.csv`:

| Column | Description | Example |
|--------|-------------|---------|
| `release` | Version tag or "dev" | v2.10 |
| `build` | Git commit hash (short) | 9239dd9 |
| `timestamp` | When benchmark was run | 2026-01-18 12:38:02 |
| `pdf_library` | PDF processing library used | ghostscript-10.05.0 |
| `source_file` | Original PDF filename | brochure.pdf |
| `source_size_bytes` | Original file size | 20971520 |
| `preset` | Compression preset used | medium |
| `compressed_size_bytes` | Resulting file size | 8388608 |
| `compression_time_ms` | Time to compress | 5845 |
| `compression_ratio` | compressed/source | 0.40 |

The `pdf_library` column enables comparing different PDF processing libraries (e.g., Ghostscript vs alternatives) across releases.

## Analyzing Results

### View Recent Results

```bash
# Formatted table of recent results
tail -30 docs/performance-history.csv | column -t -s,

# Just one release
grep "v2.10" docs/performance-history.csv | column -t -s,
```

### Compare Two Releases

```bash
# Side by side comparison
grep -E "v2.9|v2.10" docs/performance-history.csv | sort -t, -k4,4 -k6,6 | column -t -s,
```

### Calculate Averages

```bash
# Average compression ratio by release
awk -F, 'NR>1 && $9<2 {sum[$1]+=$9; count[$1]++} END {for(r in sum) print r, sum[r]/count[r]}' docs/performance-history.csv
```

## Interpreting Results

### Compression Ratio

| Ratio | Quality | Meaning |
|-------|---------|---------|
| < 0.3 | Excellent | >70% size reduction |
| 0.3 - 0.5 | Good | 50-70% reduction |
| 0.5 - 0.7 | Moderate | 30-50% reduction |
| 0.7 - 1.0 | Poor | <30% reduction |
| > 1.0 | Negative | File got LARGER |

**Note**: Ratios > 1.0 happen when source images are already compressed. This is expected for high-quality presets on already-optimized PDFs.

### Compression Time

- Small files (<5MB): Should complete in <10 seconds
- Medium files (5-20MB): May take 10-60 seconds
- Large files (>20MB): May take 1-5 minutes
- Grayscale preset: Takes 5-10x longer (color conversion)

## Release Checklist

Before each release:

1. [ ] Build the app: `./build_app.sh --with-gs`
2. [ ] Run benchmark: `./benchmark.sh vX.Y`
3. [ ] Review results for regressions (compare with previous release)
4. [ ] Check for:
   - Compression ratios significantly worse than previous release
   - Compression times significantly slower
   - Any failures (FAILED in results)
5. [ ] Commit updated `docs/performance-history.csv`
6. [ ] Note any significant performance changes in release notes

## When to Run Benchmarks

**Always run benchmarks after:**
- Changing Ghostscript command-line arguments
- Updating Ghostscript version
- Modifying PDF analysis or processing logic
- Switching to a different PDF library
- Any change to compression presets

## Comparing PDF Libraries

When evaluating alternative PDF libraries:

1. Create a branch: `git checkout -b test-new-library`
2. Implement the alternative
3. Run benchmark: `./benchmark.sh new-library-test`
4. Compare with baseline: `grep -E "v2.10|new-library" docs/performance-history.csv`
5. Document findings in `docs/improvements.md`

Key metrics to compare:
- **Compression ratio**: Does it compress as well?
- **Speed**: Is it faster or slower?
- **Quality**: Visual inspection of output PDFs
- **Compatibility**: Any PDFs that fail to process?

## Troubleshooting

### Benchmark Hangs

Large files with grayscale conversion can take 5+ minutes. If stuck:

```bash
# Check if GS is running
ps aux | grep gs

# Kill and restart
pkill -f "gs.*benchmark"
./benchmark.sh v2.10
```

### Missing Ghostscript

```bash
# Install system Ghostscript
brew install ghostscript

# Or build the app with bundled GS
./build_app.sh --with-gs
```

### Results Show FAILED

Check:
- Ghostscript is installed and working: `gs --version`
- PDF file exists and is readable
- Sufficient disk space for output files
