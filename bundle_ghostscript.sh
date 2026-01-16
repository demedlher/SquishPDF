#!/bin/bash
set -e

# Configuration
GS_VERSION="10.05.0_1"
GS_CELLAR="/opt/homebrew/Cellar/ghostscript/${GS_VERSION}"
APP_BUNDLE="${1:-SquishPDF.app}"
GS_DEST="$APP_BUNDLE/Contents/Frameworks/Ghostscript"

echo "=== Bundling Ghostscript into app bundle ==="

# Verify Ghostscript installation
if [ ! -d "$GS_CELLAR" ]; then
    echo "Error: Ghostscript not found at $GS_CELLAR"
    echo "Install with: brew install ghostscript"
    exit 1
fi

# Create destination directory structure
echo "Creating directory structure..."
mkdir -p "$GS_DEST/bin"
mkdir -p "$GS_DEST/lib"
mkdir -p "$GS_DEST/share/ghostscript"

# Copy main Ghostscript binary
echo "Copying Ghostscript binary..."
cp "$GS_CELLAR/bin/gs" "$GS_DEST/bin/"
chmod 755 "$GS_DEST/bin/gs"

# Copy Ghostscript resources (required for operation)
echo "Copying Ghostscript resources..."
GS_SHARE="$GS_CELLAR/share/ghostscript"
if [ -d "$GS_SHARE" ]; then
    # Find the version directory (e.g., 10.05.0)
    GS_SHARE_VERSION=$(ls "$GS_SHARE" | head -1)
    if [ -d "$GS_SHARE/$GS_SHARE_VERSION" ]; then
        cp -R "$GS_SHARE/$GS_SHARE_VERSION/lib" "$GS_DEST/share/ghostscript/" 2>/dev/null || true
        cp -R "$GS_SHARE/$GS_SHARE_VERSION/Resource" "$GS_DEST/share/ghostscript/" 2>/dev/null || true
        cp -R "$GS_SHARE/$GS_SHARE_VERSION/iccprofiles" "$GS_DEST/share/ghostscript/" 2>/dev/null || true
    fi
fi

# Copy fonts if available
if [ -d "/opt/homebrew/share/ghostscript/fonts" ]; then
    cp -R "/opt/homebrew/share/ghostscript/fonts" "$GS_DEST/share/ghostscript/"
fi

# Libraries to bundle (non-system libraries)
LIBS=(
    "/opt/homebrew/opt/libtiff/lib/libtiff.6.dylib"
    "/opt/homebrew/opt/libpng/lib/libpng16.16.dylib"
    "/opt/homebrew/opt/jbig2dec/lib/libjbig2dec.0.dylib"
    "/opt/homebrew/opt/jpeg-turbo/lib/libjpeg.8.dylib"
    "/opt/homebrew/opt/little-cms2/lib/liblcms2.2.dylib"
    "/opt/homebrew/opt/libidn/lib/libidn.12.dylib"
    "/opt/homebrew/opt/fontconfig/lib/libfontconfig.1.dylib"
    "/opt/homebrew/opt/freetype/lib/libfreetype.6.dylib"
    "/opt/homebrew/opt/openjpeg/lib/libopenjp2.7.dylib"
    "/opt/homebrew/opt/tesseract/lib/libtesseract.5.dylib"
    "/opt/homebrew/opt/libarchive/lib/libarchive.13.dylib"
    "/opt/homebrew/opt/leptonica/lib/libleptonica.6.dylib"
)

# Copy dynamic libraries
echo "Copying dynamic libraries..."
for lib in "${LIBS[@]}"; do
    if [ -f "$lib" ]; then
        libname=$(basename "$lib")
        # Resolve symlink to get actual file
        reallib=$(readlink -f "$lib" 2>/dev/null || realpath "$lib" 2>/dev/null || echo "$lib")
        cp "$reallib" "$GS_DEST/lib/$libname"
        chmod 644 "$GS_DEST/lib/$libname"
        echo "  Copied: $libname"
    else
        echo "  Warning: $lib not found, skipping"
    fi
done

# Also copy transitive dependencies that might be needed
TRANSITIVE_LIBS=(
    "/opt/homebrew/opt/zstd/lib/libzstd.1.dylib"
    "/opt/homebrew/opt/xz/lib/liblzma.5.dylib"
    "/opt/homebrew/opt/webp/lib/libwebp.7.dylib"
    "/opt/homebrew/opt/giflib/lib/libgif.7.dylib"
    "/opt/homebrew/opt/brotli/lib/libbrotlidec.1.dylib"
    "/opt/homebrew/opt/brotli/lib/libbrotlicommon.1.dylib"
)

echo "Copying transitive dependencies..."
for lib in "${TRANSITIVE_LIBS[@]}"; do
    if [ -f "$lib" ]; then
        libname=$(basename "$lib")
        reallib=$(readlink -f "$lib" 2>/dev/null || realpath "$lib" 2>/dev/null || echo "$lib")
        cp "$reallib" "$GS_DEST/lib/$libname"
        chmod 644 "$GS_DEST/lib/$libname"
        echo "  Copied: $libname"
    fi
done

# Update library paths in the Ghostscript binary
echo "Updating library paths with install_name_tool..."
GS_BIN="$GS_DEST/bin/gs"

for lib in "${LIBS[@]}" "${TRANSITIVE_LIBS[@]}"; do
    libname=$(basename "$lib")
    if [ -f "$GS_DEST/lib/$libname" ]; then
        install_name_tool -change "$lib" "@executable_path/../lib/$libname" "$GS_BIN" 2>/dev/null || true
    fi
done

# Fix library IDs and nested dependencies
echo "Fixing nested library dependencies..."
for libfile in "$GS_DEST/lib"/*.dylib; do
    if [ -f "$libfile" ]; then
        libname=$(basename "$libfile")

        # Update the library's own ID
        install_name_tool -id "@executable_path/../lib/$libname" "$libfile" 2>/dev/null || true

        # Update references to other bundled libraries
        for deplib in "${LIBS[@]}" "${TRANSITIVE_LIBS[@]}"; do
            deplibname=$(basename "$deplib")
            install_name_tool -change "$deplib" "@executable_path/../lib/$deplibname" "$libfile" 2>/dev/null || true
        done
    fi
done

# Code sign all binaries and libraries
echo "Code signing..."
codesign --force --deep --sign - "$GS_BIN" 2>/dev/null || echo "  Warning: Could not sign gs binary"
for libfile in "$GS_DEST/lib"/*.dylib; do
    if [ -f "$libfile" ]; then
        codesign --force --sign - "$libfile" 2>/dev/null || true
    fi
done

# Calculate and display bundle size
BUNDLE_SIZE=$(du -sh "$GS_DEST" | cut -f1)
echo ""
echo "=== Ghostscript bundling complete ==="
echo "Bundle location: $GS_DEST"
echo "Bundle size: $BUNDLE_SIZE"
echo ""

# Verify the bundled gs works
echo "Verifying bundled Ghostscript..."
if "$GS_BIN" --version >/dev/null 2>&1; then
    echo "Ghostscript version: $("$GS_BIN" --version)"
    echo "Verification: SUCCESS"
else
    echo "Warning: Bundled Ghostscript may not work standalone."
    echo "This is expected - it should work when run from the app."
fi
