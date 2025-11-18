#!/bin/bash
# Increment build number in Version.json

set -e

VERSION_FILE="Version.json"

# Check if Version.json exists
if [ ! -f "$VERSION_FILE" ]; then
    echo "Error: $VERSION_FILE not found"
    exit 1
fi

# Read current build number
current_build=$(grep -o '"build":[[:space:]]*[0-9]*' "$VERSION_FILE" | grep -o '[0-9]*')

# Increment build number
new_build=$((current_build + 1))

# Update Version.json with new build number (preserving formatting)
sed -i '' "s/\"build\":[[:space:]]*[0-9]*/\"build\": $new_build/" "$VERSION_FILE"

echo "Build number incremented: $current_build -> $new_build"
