#!/bin/bash

# Build both SquishPDF installer variants:
# 1. Full version with Ghostscript bundled (~100MB)
# 2. Lean version without Ghostscript (~5MB, requires user to install GS)

set -e

echo "========================================"
echo "  Building SquishPDF Installer Variants"
echo "========================================"
echo ""

# Build full version first (with Ghostscript)
echo ">>> Building FULL version (with Ghostscript bundled)..."
./build_app.sh --with-gs

# Preserve the full DMG
mv SquishPDF_Installer.dmg SquishPDF_Installer_Full.dmg 2>/dev/null || true

echo ""
echo ">>> Building LEAN version (without Ghostscript)..."
./build_app.sh --no-gs

echo ""
echo "========================================"
echo "  Build Complete!"
echo "========================================"
echo ""
echo "Generated installers:"
echo "  1. SquishPDF_Installer_Full.dmg  - Includes Ghostscript (~100MB)"
echo "  2. SquishPDF_Installer_Lean.dmg  - Requires 'brew install ghostscript' (~5MB)"
echo ""
echo "For most users, distribute the Full version."
echo "The Lean version is for users who already have Ghostscript installed."
