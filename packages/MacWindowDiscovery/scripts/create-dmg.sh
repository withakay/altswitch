#!/bin/bash
# Create DMG package for MacWindowDiscovery release

set -e

# Configuration
VERSION_FILE="Version.json"
BUILD_DIR=".build/release"
DIST_DIR="dist"
CLI_BINARY="mac-window-discovery"
DEBUG_BINARY="mac-window-discovery-debug"

# Read version from Version.json
if [ ! -f "$VERSION_FILE" ]; then
    echo "❌ Error: $VERSION_FILE not found"
    exit 1
fi

VERSION=$(grep -o '"version":[[:space:]]*"[^"]*"' "$VERSION_FILE" | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
BUILD=$(grep -o '"build":[[:space:]]*[0-9]*' "$VERSION_FILE" | grep -o '[0-9]*')

# Check if release binaries exist
if [ ! -f "$BUILD_DIR/$CLI_BINARY" ]; then
    echo "❌ Error: Release binary not found at $BUILD_DIR/$CLI_BINARY"
    echo "Run 'make build-release' first"
    exit 1
fi

# Create dist directory
mkdir -p "$DIST_DIR"

# Create temporary directory for DMG contents
DMG_TEMP="$DIST_DIR/dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Copy binaries
echo "📦 Copying binaries..."
cp "$BUILD_DIR/$CLI_BINARY" "$DMG_TEMP/"
cp "$BUILD_DIR/$DEBUG_BINARY" "$DMG_TEMP/"

# Create a simple README
cat > "$DMG_TEMP/README.txt" << EOF
MacWindowDiscovery v$VERSION (Build $BUILD)

This package contains:
- mac-window-discovery: Command-line tool for window discovery
- mac-window-discovery-debug: Debug GUI application

Installation:
1. Copy 'mac-window-discovery' to /usr/local/bin/ or any directory in your PATH
2. Make executable: chmod +x mac-window-discovery
3. Run: mac-window-discovery --help

For more information, visit:
https://github.com/withakay/altswitch
EOF

# DMG filename
DMG_NAME="MacWindowDiscovery-$VERSION-build$BUILD.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

# Remove existing DMG if it exists
rm -f "$DMG_PATH"

echo "🔨 Creating DMG: $DMG_NAME"

# Create DMG
hdiutil create -volname "MacWindowDiscovery $VERSION" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_PATH"

# Clean up temp directory
rm -rf "$DMG_TEMP"

# Get file size
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)

echo "✅ DMG created successfully!"
echo "   Location: $DMG_PATH"
echo "   Size: $DMG_SIZE"
