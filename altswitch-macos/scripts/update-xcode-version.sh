#!/bin/bash
# Update Xcode project version from Version.json

set -e

VERSION_FILE="Version.json"
PROJECT_FILE="AltSwitch.xcodeproj/project.pbxproj"

# Check if files exist
if [ ! -f "$VERSION_FILE" ]; then
    echo "Error: $VERSION_FILE not found"
    exit 1
fi

if [ ! -f "$PROJECT_FILE" ]; then
    echo "Error: $PROJECT_FILE not found"
    exit 1
fi

# Read version and build from Version.json
version=$(grep -o '"version":[[:space:]]*"[^"]*"' "$VERSION_FILE" | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
build=$(grep -o '"build":[[:space:]]*[0-9]*' "$VERSION_FILE" | grep -o '[0-9]*')

# Update MARKETING_VERSION in project.pbxproj
sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $version/" "$PROJECT_FILE"

# Update CURRENT_PROJECT_VERSION in project.pbxproj (build number)
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $build/" "$PROJECT_FILE"

echo "Xcode project updated:"
echo "  MARKETING_VERSION: $version"
echo "  CURRENT_PROJECT_VERSION: $build"
