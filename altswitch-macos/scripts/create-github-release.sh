#!/bin/bash
# Create GitHub release with DMG and ZIP archives for AltSwitch

set -e

# Configuration
VERSION_FILE="Version.json"
DIST_DIR="dist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
    echo "Install with: brew install gh"
    echo "Then authenticate: gh auth login"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Not authenticated with GitHub${NC}"
    echo "Run: gh auth login"
    exit 1
fi

# Read version from Version.json
if [ ! -f "$VERSION_FILE" ]; then
    echo -e "${RED}❌ Error: $VERSION_FILE not found${NC}"
    exit 1
fi

VERSION=$(grep -o '"version":[[:space:]]*"[^"]*"' "$VERSION_FILE" | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
BUILD=$(grep -o '"build":[[:space:]]*[0-9]*' "$VERSION_FILE" | grep -o '[0-9]*')

TAG="v$VERSION"
RELEASE_TITLE="AltSwitch v$VERSION (Build $BUILD)"

echo -e "${GREEN}📦 Creating GitHub Release${NC}"
echo "  Version: $VERSION"
echo "  Build: $BUILD"
echo "  Tag: $TAG"
echo ""

# Check if dist files exist
DMG_FILE="$DIST_DIR/AltSwitch-$VERSION-build$BUILD.dmg"
ZIP_FILE="$DIST_DIR/AltSwitch-$VERSION-build$BUILD.zip"

if [ ! -f "$DMG_FILE" ]; then
    echo -e "${RED}❌ Error: DMG file not found: $DMG_FILE${NC}"
    echo "Run 'make build-release' or 'make package' first"
    exit 1
fi

if [ ! -f "$ZIP_FILE" ]; then
    echo -e "${RED}❌ Error: ZIP file not found: $ZIP_FILE${NC}"
    echo "Run 'make build-release' or 'make package' first"
    exit 1
fi

# Check if tag already exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Tag $TAG already exists${NC}"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting local tag..."
        git tag -d "$TAG"
        echo "Deleting remote tag..."
        git push origin ":refs/tags/$TAG" 2>/dev/null || true
    else
        echo "Aborting."
        exit 1
    fi
fi

# Generate release notes from commits since last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

echo -e "${GREEN}📝 Generating release notes...${NC}"

if [ -z "$LAST_TAG" ]; then
    echo "  No previous tag found, using all commits"
    COMMITS=$(git log --pretty=format:"- %s (%h)" --no-merges)
else
    echo "  Changes since $LAST_TAG"
    COMMITS=$(git log "$LAST_TAG..HEAD" --pretty=format:"- %s (%h)" --no-merges)
fi

# Create release notes file
NOTES_FILE=$(mktemp)
cat > "$NOTES_FILE" << EOF
# AltSwitch v$VERSION

Build: $BUILD

## What's Changed

$COMMITS

## Installation

### Direct Install (Recommended)

1. Download the DMG file below
2. Open the DMG and drag AltSwitch to Applications
3. Launch AltSwitch from Applications
4. Grant required permissions:
   - Accessibility (System Settings > Privacy & Security > Accessibility)
   - Input Monitoring (System Settings > Privacy & Security > Input Monitoring)

### Alternative Install

1. Download the ZIP file below
2. Unzip and drag AltSwitch.app to Applications
3. Right-click and select "Open" for first launch (bypasses Gatekeeper)
4. Grant required permissions

## Features

- **Fast App Switching**: Spotlight-style interface with fuzzy search
- **Global Hotkeys**: Customizable keyboard shortcuts
- **Cross-Space Support**: Switch to apps on any macOS Space
- **Liquid Glass UI**: Modern macOS 15+ visual effects

## System Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permissions
- Input Monitoring permissions

## Downloads

- **DMG**: macOS disk image with drag-to-Applications installer (recommended)
- **ZIP**: Direct archive for manual installation

---

**Full Changelog**: https://github.com/withakay/altswitch/compare/${LAST_TAG}...${TAG}
EOF

echo ""
echo -e "${GREEN}📋 Release Notes:${NC}"
echo "---"
cat "$NOTES_FILE"
echo "---"
echo ""

# Confirm before creating release
read -p "Create release and upload assets? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    rm "$NOTES_FILE"
    exit 1
fi

# Create and push tag
echo -e "${GREEN}🏷️  Creating tag $TAG...${NC}"
git tag -a "$TAG" -m "Release $VERSION (Build $BUILD)"
git push origin "$TAG"

# Create GitHub release
echo -e "${GREEN}🚀 Creating GitHub release...${NC}"
gh release create "$TAG" \
    --title "$RELEASE_TITLE" \
    --notes-file "$NOTES_FILE" \
    "$DMG_FILE" \
    "$ZIP_FILE"

# Clean up
rm "$NOTES_FILE"

echo ""
echo -e "${GREEN}✅ GitHub release created successfully!${NC}"
echo ""
echo "Release URL: https://github.com/withakay/altswitch/releases/tag/$TAG"
echo ""
echo "Uploaded assets:"
echo "  - $(basename "$DMG_FILE") ($(du -h "$DMG_FILE" | cut -f1))"
echo "  - $(basename "$ZIP_FILE") ($(du -h "$ZIP_FILE" | cut -f1))"
