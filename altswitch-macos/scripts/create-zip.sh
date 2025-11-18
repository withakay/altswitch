#!/bin/bash
# Create ZIP archive for AltSwitch release

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

# Create temporary directory for ZIP contents
ZIP_TEMP="$DIST_DIR/zip_temp"
ZIP_FOLDER="AltSwitch-$VERSION"
rm -rf "$ZIP_TEMP"
mkdir -p "$ZIP_TEMP/$ZIP_FOLDER"

# Copy app bundle
echo "📦 Copying AltSwitch.app..."
cp -R "$DIST_DIR/$APP_NAME" "$ZIP_TEMP/$ZIP_FOLDER/"

# Create a simple README
cat > "$ZIP_TEMP/$ZIP_FOLDER/README.txt" << EOF
AltSwitch v$VERSION (Build $BUILD)

Installation:
1. Unzip this archive
2. Drag AltSwitch.app to your Applications folder
3. Open AltSwitch from Applications
4. Grant Accessibility and Input Monitoring permissions when prompted
5. Configure your hotkeys in Preferences

For more information, visit:
https://github.com/withakay/altswitch

System Requirements:
- macOS 13.0 (Ventura) or later
- Accessibility permissions
- Input Monitoring permissions
EOF

# ZIP filename
ZIP_NAME="AltSwitch-$VERSION-build$BUILD.zip"
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
