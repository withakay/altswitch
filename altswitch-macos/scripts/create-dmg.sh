#!/bin/bash
# Create DMG package for AltSwitch release

set -e

# Configuration
VERSION_FILE="Version.json"
DIST_DIR="dist"
APP_NAME="AltSwitch.app"

# Read version from Version.json
if [ ! -f "$VERSION_FILE" ]; then
    echo "❌ Error: $VERSION_FILE not found"
    exit 1
fi

VERSION=$(grep -o '"version":[[:space:]]*"[^"]*"' "$VERSION_FILE" | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
BUILD=$(grep -o '"build":[[:space:]]*[0-9]*' "$VERSION_FILE" | grep -o '[0-9]*')

# Check if app bundle exists in dist
if [ ! -d "$DIST_DIR/$APP_NAME" ]; then
    echo "❌ Error: $DIST_DIR/$APP_NAME not found"
    echo "Run 'make build-release' first"
    exit 1
fi

# Create temporary directory for DMG contents
DMG_TEMP="$DIST_DIR/dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Copy app bundle
echo "📦 Copying AltSwitch.app..."
cp -R "$DIST_DIR/$APP_NAME" "$DMG_TEMP/"

# Create symbolic link to Applications folder
echo "📦 Creating Applications symlink..."
ln -s /Applications "$DMG_TEMP/Applications"

# Create a simple README
cat > "$DMG_TEMP/README.txt" << EOF
AltSwitch v$VERSION (Build $BUILD)

Installation:
1. Drag AltSwitch.app to the Applications folder
2. Open AltSwitch from Applications
3. Grant Accessibility and Input Monitoring permissions when prompted
4. Configure your hotkeys in Preferences

For more information, visit:
https://github.com/withakay/altswitch

System Requirements:
- macOS 13.0 (Ventura) or later
- Accessibility permissions
- Input Monitoring permissions
EOF

# DMG filename
DMG_NAME="AltSwitch-$VERSION-build$BUILD.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

# Remove existing DMG if it exists
rm -f "$DMG_PATH"

echo "🔨 Creating DMG: $DMG_NAME"

# Create DMG
hdiutil create -volname "AltSwitch $VERSION" \
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
