#!/bin/bash

# Use the custom SquishPDF icon
SOURCE_ICON="images/SquishPDF-icon-square.png"

if [ ! -f "$SOURCE_ICON" ]; then
    echo "Error: Icon source not found at $SOURCE_ICON"
    exit 1
fi

# Create iconset directory
rm -rf AppIcon.iconset
mkdir AppIcon.iconset

# Resize to 1024x1024 as base
sips -z 1024 1024 "$SOURCE_ICON" --out icon.png

# Generate different icon sizes with high quality
sips -s format png -z 16 16     icon.png --out AppIcon.iconset/icon_16x16.png
sips -s format png -z 32 32     icon.png --out AppIcon.iconset/icon_16x16@2x.png
sips -s format png -z 32 32     icon.png --out AppIcon.iconset/icon_32x32.png
sips -s format png -z 64 64     icon.png --out AppIcon.iconset/icon_32x32@2x.png
sips -s format png -z 128 128   icon.png --out AppIcon.iconset/icon_128x128.png
sips -s format png -z 256 256   icon.png --out AppIcon.iconset/icon_128x128@2x.png
sips -s format png -z 256 256   icon.png --out AppIcon.iconset/icon_256x256.png
sips -s format png -z 512 512   icon.png --out AppIcon.iconset/icon_256x256@2x.png
sips -s format png -z 512 512   icon.png --out AppIcon.iconset/icon_512x512.png
sips -s format png -z 1024 1024 icon.png --out AppIcon.iconset/icon_512x512@2x.png

# Create icns file with high quality settings
iconutil --convert icns --output AppIcon.icns AppIcon.iconset

# Ensure Resources directory exists
mkdir -p SquishPDF.app/Contents/Resources

# Install icon and set permissions
cp AppIcon.icns SquishPDF.app/Contents/Resources/
chmod 644 SquishPDF.app/Contents/Resources/AppIcon.icns

# Touch the app bundle to refresh
touch SquishPDF.app

# Clean up
rm -f icon.png
rm -rf AppIcon.iconset

echo "Icon created successfully from $SOURCE_ICON"
