#!/bin/bash
#
# SquishPDF Performance Benchmark Script
#
# This script runs all compression presets on all sample PDFs and records
# the results in docs/performance-history.csv for tracking over releases.
#
# Usage: ./benchmark.sh [release_tag]
#   release_tag: Optional version tag (e.g., "v2.10"). If not provided,
#                uses the current git tag or "dev".
#
# Sample PDFs should be placed in sample-docs/ folder.
# Only original files (without preset suffixes) are tested.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLE_DIR="$SCRIPT_DIR/sample-docs"
OUTPUT_DIR="$SCRIPT_DIR/benchmark-output"
RESULTS_FILE="$SCRIPT_DIR/docs/performance-history.csv"

# Get release tag from argument or git
if [ -n "$1" ]; then
    RELEASE="$1"
else
    RELEASE=$(git describe --tags --exact-match 2>/dev/null || echo "dev")
fi

# Get build info
BUILD_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# All presets to test
PRESETS=("tiny" "small" "medium" "large" "xlarge" "grayscale" "web")

# Find Ghostscript - check bundled first, then system
if [ -x "$SCRIPT_DIR/SquishPDF.app/Contents/Frameworks/Ghostscript/bin/gs" ]; then
    GS_PATH="$SCRIPT_DIR/SquishPDF.app/Contents/Frameworks/Ghostscript/bin/gs"
elif command -v gs &> /dev/null; then
    GS_PATH=$(command -v gs)
else
    echo "Error: Ghostscript not found. Build the app first or install with: brew install ghostscript"
    exit 1
fi

echo "=========================================="
echo "  SquishPDF Performance Benchmark"
echo "=========================================="
echo "Release: $RELEASE"
echo "Build:   $BUILD_HASH"
echo "Date:    $TIMESTAMP"
echo "GS:      $GS_PATH"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Create CSV header if file doesn't exist
if [ ! -f "$RESULTS_FILE" ]; then
    echo "release,build,timestamp,source_file,source_size_bytes,preset,compressed_size_bytes,compression_time_ms,compression_ratio" > "$RESULTS_FILE"
fi

# Get GS arguments for each preset
get_gs_args() {
    local preset=$1
    local source_dpi=$2

    case $preset in
        tiny)
            echo "-dPDFSETTINGS=/screen -dColorImageResolution=36 -dGrayImageResolution=36 -dMonoImageResolution=36"
            ;;
        small)
            echo "-dPDFSETTINGS=/screen"
            ;;
        medium)
            echo "-dPDFSETTINGS=/ebook"
            ;;
        large)
            echo "-dPDFSETTINGS=/printer"
            ;;
        xlarge)
            echo "-dPDFSETTINGS=/prepress"
            ;;
        grayscale)
            echo "-dPDFSETTINGS=/ebook -sColorConversionStrategy=Gray -dProcessColorModel=/DeviceGray -dColorImageResolution=${source_dpi:-150} -dGrayImageResolution=${source_dpi:-150}"
            ;;
        web)
            echo "-dPDFSETTINGS=/screen -dFastWebView=true"
            ;;
    esac
}

# Estimate source DPI using pdfimages (if available) or default
get_source_dpi() {
    local pdf_file=$1
    # Simple estimation - could be enhanced
    echo "150"
}

# Process each sample PDF (only originals, not already-compressed versions)
for pdf_file in "$SAMPLE_DIR"/*.pdf; do
    filename=$(basename "$pdf_file")

    # Skip files that have preset suffixes (already compressed)
    if [[ "$filename" =~ -(tiny|small|medium|large|xlarge|grayscale|web)- ]]; then
        continue
    fi

    source_size=$(stat -f%z "$pdf_file")
    source_dpi=$(get_source_dpi "$pdf_file")

    echo "Processing: $filename ($((source_size / 1024 / 1024)) MB)"
    echo "-------------------------------------------"

    for preset in "${PRESETS[@]}"; do
        output_file="$OUTPUT_DIR/${filename%.pdf}-${preset}-benchmark.pdf"
        gs_args=$(get_gs_args "$preset" "$source_dpi")

        # Run compression and measure time
        start_time=$(python3 -c "import time; print(int(time.time() * 1000))")

        "$GS_PATH" -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 \
            -dNOPAUSE -dQUIET -dBATCH \
            $gs_args \
            -sOutputFile="$output_file" \
            "$pdf_file" 2>/dev/null

        end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
        compression_time=$((end_time - start_time))

        # Get compressed size
        if [ -f "$output_file" ]; then
            compressed_size=$(stat -f%z "$output_file")
            ratio=$(python3 -c "print(f'{$compressed_size / $source_size:.4f}')")

            printf "  %-10s: %8d bytes -> %8d bytes (%.1f%%) in %d ms\n" \
                "$preset" "$source_size" "$compressed_size" \
                "$(python3 -c "print(f'{(1 - $compressed_size / $source_size) * 100:.1f}')")" \
                "$compression_time"

            # Append to CSV
            echo "$RELEASE,$BUILD_HASH,$TIMESTAMP,$filename,$source_size,$preset,$compressed_size,$compression_time,$ratio" >> "$RESULTS_FILE"

            # Clean up benchmark output
            rm -f "$output_file"
        else
            echo "  $preset: FAILED"
            echo "$RELEASE,$BUILD_HASH,$TIMESTAMP,$filename,$source_size,$preset,FAILED,0,0" >> "$RESULTS_FILE"
        fi
    done
    echo ""
done

# Clean up output directory
rmdir "$OUTPUT_DIR" 2>/dev/null || true

echo "=========================================="
echo "  Benchmark Complete"
echo "=========================================="
echo "Results appended to: $RESULTS_FILE"
echo ""
echo "To view recent results:"
echo "  tail -20 $RESULTS_FILE | column -t -s,"
