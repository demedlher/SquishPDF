#!/bin/bash

# Exit on error
set -e

echo "Building PDFConverter..."

# Build the Swift package
swift build -c release

# Create app bundle structure
APP_NAME="PDFConverter"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Remove existing app bundle if it exists
rm -rf "$APP_BUNDLE"

# Create directory structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp .build/release/PDFConverter "$MACOS_DIR/"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PDFConverter</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.pdfconverter</string>
    <key>CFBundleName</key>
    <string>PDFConverter</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDisplayName</key>
    <string>PDFConverter</string>
    <key>CFBundleGetInfoString</key>
    <string>PDFConverter</string>
</dict>
</plist>
EOF

# Generate and install icon
./create_icon.sh

# Set permissions
chmod 755 "$APP_BUNDLE"
chmod 755 "$CONTENTS_DIR"
chmod 755 "$MACOS_DIR"
chmod 755 "$RESOURCES_DIR"
chmod 755 "$MACOS_DIR/PDFConverter"
chmod 644 "$CONTENTS_DIR/Info.plist"

echo "Creating DMG..."
./create_dmg.sh

echo "Build complete!" 