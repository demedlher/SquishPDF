#!/bin/bash

# Exit on error
set -e

echo "=== Building SquishPDF v2.7 ==="

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
    <string>2.7</string>
    <key>CFBundleVersion</key>
    <string>2.7.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDisplayName</key>
    <string>SquishPDF</string>
    <key>CFBundleGetInfoString</key>
    <string>SquishPDF v2.7 - Powered by Ghostscript</string>
</dict>
</plist>
EOF

# Generate and install icon
echo "Generating app icon..."
./create_icon.sh

# Bundle Ghostscript
echo "Bundling Ghostscript..."
./bundle_ghostscript.sh

# Create licenses directory
mkdir -p "$RESOURCES_DIR/LICENSES"

# Copy MIT license
if [ -f "LICENSE" ]; then
    cp LICENSE "$RESOURCES_DIR/LICENSES/SquishPDF-LICENSE.txt"
fi

# Add Ghostscript license notice
cat > "$RESOURCES_DIR/LICENSES/Ghostscript-LICENSE.txt" << EOF
Ghostscript is licensed under the GNU Affero General Public License (AGPL) version 3.

Copyright (C) 2001-2025 Artifex Software, Inc.

This application bundles Ghostscript for PDF compression.
For full license text, see: https://www.ghostscript.com/licensing/

For commercial licensing inquiries, contact Artifex Software.
EOF

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
./create_dmg.sh

echo ""
echo "=== Build complete! ==="
echo "App bundle: $APP_BUNDLE"
echo "DMG installer: SquishPDF_Installer.dmg"
