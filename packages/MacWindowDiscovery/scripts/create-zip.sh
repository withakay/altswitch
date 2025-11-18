#!/bin/bash
# Create ZIP archive for MacWindowDiscovery release

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

# Create temporary directory for ZIP contents
ZIP_TEMP="$DIST_DIR/zip_temp"
ZIP_FOLDER="MacWindowDiscovery-$VERSION"
rm -rf "$ZIP_TEMP"
mkdir -p "$ZIP_TEMP/$ZIP_FOLDER"

# Copy binaries
echo "📦 Copying binaries..."
cp "$BUILD_DIR/$CLI_BINARY" "$ZIP_TEMP/$ZIP_FOLDER/"
cp "$BUILD_DIR/$DEBUG_BINARY" "$ZIP_TEMP/$ZIP_FOLDER/"

# Create a simple README
cat > "$ZIP_TEMP/$ZIP_FOLDER/README.txt" << EOF
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

# ZIP filename
ZIP_NAME="MacWindowDiscovery-$VERSION-build$BUILD.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

# Remove existing ZIP if it exists
rm -f "$ZIP_PATH"

echo "🔨 Creating ZIP: $ZIP_NAME"

# Create ZIP (using ditto for better macOS compatibility)
cd "$ZIP_TEMP"
zip -r "../$ZIP_NAME" "$ZIP_FOLDER" -q
cd - > /dev/null

# Clean up temp directory
rm -rf "$ZIP_TEMP"

# Get file size
ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)

echo "✅ ZIP created successfully!"
echo "   Location: $ZIP_PATH"
echo "   Size: $ZIP_SIZE"
