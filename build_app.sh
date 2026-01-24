#!/bin/bash

# Exit on error
set -e

# Parse arguments
# v4.0+: Native compression is default (no Ghostscript, App Store compatible)
# Use --with-gs only for legacy Ghostscript builds (AGPL licensed)
BUNDLE_GS=false
DMG_SUFFIX=""

for arg in "$@"; do
    case $arg in
        --with-gs)
            BUNDLE_GS=true
            DMG_SUFFIX="_GS"
            echo "WARNING: Building with Ghostscript (AGPL licensed - not for commercial distribution)"
            ;;
        --no-gs)
            # Legacy flag, now the default
            BUNDLE_GS=false
            DMG_SUFFIX=""
            ;;
        *)
            ;;
    esac
done

# Get current version info
VERSION_FILE="Sources/SquishPDF/AppVersion.swift"
CURRENT_VERSION=$(grep 'static let version' "$VERSION_FILE" | sed 's/.*"\(.*\)".*/\1/')
CURRENT_BUILD=$(grep 'static let build' "$VERSION_FILE" | sed 's/[^0-9]*\([0-9]*\).*/\1/')
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Increment build number
NEW_BUILD=$((CURRENT_BUILD + 1))

# Update AppVersion.swift
sed -i '' "s/static let build = [0-9]*/static let build = $NEW_BUILD/" "$VERSION_FILE"
sed -i '' "s/static let commit = \"[^\"]*\"/static let commit = \"$GIT_COMMIT\"/" "$VERSION_FILE"

echo "=== Building SquishPDF v${CURRENT_VERSION}.${NEW_BUILD} (${GIT_COMMIT}) ==="
if [ "$BUNDLE_GS" = true ]; then
    echo "    (Ghostscript build - AGPL licensed)"
else
    echo "    (Native build - commercially distributable)"
fi

# Build the Swift package
echo "Compiling Swift code..."
swift build -c release

# Create app bundle structure
APP_NAME="SquishPDF"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

# Remove existing app bundle if it exists
rm -rf "$APP_BUNDLE"

# Create directory structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$FRAMEWORKS_DIR"

# Copy executable
cp .build/release/SquishPDF "$MACOS_DIR/"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SquishPDF</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.demedlher.squishpdf</string>
    <key>CFBundleName</key>
    <string>SquishPDF</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${CURRENT_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${CURRENT_VERSION}.${NEW_BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDisplayName</key>
    <string>SquishPDF</string>
    <key>CFBundleGetInfoString</key>
    <string>SquishPDF v${CURRENT_VERSION} - Native PDF Compression</string>
</dict>
</plist>
EOF

# Generate and install icon
echo "Generating app icon..."
./create_icon.sh

# Bundle Ghostscript (optional)
if [ "$BUNDLE_GS" = true ]; then
    echo "Bundling Ghostscript..."
    ./bundle_ghostscript.sh "$APP_BUNDLE"
else
    echo "Skipping Ghostscript bundling (lean build)"
fi

# Create licenses directory
mkdir -p "$RESOURCES_DIR/LICENSES"

# Copy app license
if [ -f "LICENSE" ]; then
    cp LICENSE "$RESOURCES_DIR/LICENSES/SquishPDF-LICENSE.txt"
fi

# Add Ghostscript license notice only if bundling GS
if [ "$BUNDLE_GS" = true ]; then
    cat > "$RESOURCES_DIR/LICENSES/Ghostscript-LICENSE.txt" << EOF
Ghostscript is licensed under the GNU Affero General Public License (AGPL) version 3.

Copyright (C) 2001-2025 Artifex Software, Inc.

This application bundles Ghostscript for PDF compression.
For full license text, see: https://www.ghostscript.com/licensing/

For commercial licensing inquiries, contact Artifex Software.
EOF
fi

# Set permissions
chmod 755 "$APP_BUNDLE"
chmod 755 "$CONTENTS_DIR"
chmod 755 "$MACOS_DIR"
chmod 755 "$RESOURCES_DIR"
chmod 755 "$FRAMEWORKS_DIR"
chmod 755 "$MACOS_DIR/SquishPDF"
chmod 644 "$CONTENTS_DIR/Info.plist"

echo ""
echo "Creating DMG installer..."
./create_dmg.sh "$DMG_SUFFIX"

echo ""
echo "=== Build complete! ==="
echo "App bundle: $APP_BUNDLE"
if [ "$BUNDLE_GS" = true ]; then
    echo "DMG installer: SquishPDF_Installer_GS.dmg (with Ghostscript - AGPL licensed)"
else
    echo "DMG installer: SquishPDF_Installer.dmg (Native compression - commercially distributable)"
fi
