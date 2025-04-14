#!/bin/bash

# Set variables
APP_NAME="PDFConverter"
DMG_NAME="${APP_NAME}_Installer"
DMG_TEMP_NAME="${DMG_NAME}_temp.dmg"
DMG_FINAL_NAME="${DMG_NAME}.dmg"
VOLUME_NAME="PDF Converter"

# Create temporary directory for DMG contents
rm -rf dmg_contents
mkdir -p dmg_contents/.background

# Create background image
cat << EOF > dmg_contents/.background/background.svg
<?xml version="1.0" encoding="UTF-8"?>
<svg width="540" height="380" xmlns="http://www.w3.org/2000/svg">
    <rect width="540" height="380" fill="#FFFFFF"/>
    <text x="270" y="340" 
          font-family="Helvetica" 
          font-size="14" 
          text-anchor="middle" 
          fill="#666666">
        Drag PDFConverter to the Applications folder to install
    </text>
</svg>
EOF

# Convert background SVG to PNG
/usr/bin/qlmanage -t -s 1024 -o dmg_contents/.background dmg_contents/.background/background.svg
mv dmg_contents/.background/background.svg.png dmg_contents/.background/background.png

# Copy application to dmg_contents
cp -r "${APP_NAME}.app" dmg_contents/

# Create symlink to Applications folder
ln -s /Applications dmg_contents/Applications

# Create temporary DMG
hdiutil create -size 200m -volname "${VOLUME_NAME}" -srcfolder dmg_contents -format UDRW "${DMG_TEMP_NAME}"

# Mount the temporary DMG
MOUNT_DIR="/Volumes/${VOLUME_NAME}"
hdiutil attach "${DMG_TEMP_NAME}"

# Set the background image
mkdir -p "${MOUNT_DIR}/.background"
cp dmg_contents/.background/background.png "${MOUNT_DIR}/.background/"

# Set up visual appearance
echo '
   tell application "Finder"
     tell disk "'${VOLUME_NAME}'"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set the bounds of container window to {400, 100, 940, 480}
           set theViewOptions to the icon view options of container window
           set arrangement of theViewOptions to not arranged
           set icon size of theViewOptions to 128
           set background picture of theViewOptions to file ".background:background.png"
           set position of item "'${APP_NAME}'.app" of container window to {128, 180}
           set position of item "Applications" of container window to {410, 180}
           update without registering applications
           delay 2
           close
     end tell
   end tell
' | osascript

# Finalize the DMG
sync
hdiutil detach "${MOUNT_DIR}" -force
hdiutil convert "${DMG_TEMP_NAME}" -format UDZO -imagekey zlib-level=9 -o "${DMG_FINAL_NAME}"
rm -f "${DMG_TEMP_NAME}"

# Clean up
rm -rf dmg_contents 