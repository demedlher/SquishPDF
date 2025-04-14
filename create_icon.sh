#!/bin/bash

# Create temporary SVG file
cat << EOF > icon.svg
<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" xmlns="http://www.w3.org/2000/svg">
    <!-- Background with rounded corners -->
    <rect x="0" y="0" width="1024" height="1024" rx="180" ry="180" fill="#E8E8E8"/>
    
    <!-- PDF text with slight shadow for depth -->
    <text x="512" y="612" 
          font-family="Helvetica-Bold, Helvetica" 
          font-size="380" 
          font-weight="bold" 
          fill="#FF3B30" 
          text-anchor="middle"
          filter="url(#shadow)">
        PDF
    </text>
    
    <!-- Define shadow filter -->
    <defs>
        <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur in="SourceAlpha" stdDeviation="20"/>
            <feOffset dx="0" dy="10" result="offsetblur"/>
            <feComponentTransfer>
                <feFuncA type="linear" slope="0.3"/>
            </feComponentTransfer>
            <feMerge>
                <feMergeNode/>
                <feMergeNode in="SourceGraphic"/>
            </feMerge>
        </filter>
    </defs>
</svg>
EOF

# Create iconset directory
rm -rf AppIcon.iconset
mkdir AppIcon.iconset

# Convert SVG to PNG using native macOS commands
/usr/bin/qlmanage -t -s 1024 -o . icon.svg
mv icon.svg.png icon.png

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
mkdir -p PDFConverter.app/Contents/Resources

# Install icon and set permissions
cp AppIcon.icns PDFConverter.app/Contents/Resources/
chmod 644 PDFConverter.app/Contents/Resources/AppIcon.icns

# Touch the app bundle to refresh
touch PDFConverter.app

# Clean up
rm -f icon.png icon.svg
rm -rf AppIcon.iconset 