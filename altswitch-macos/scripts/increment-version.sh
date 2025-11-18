#!/bin/bash
# Increment patch version in Version.json
# Usage: ./increment-version.sh [major|minor|patch]
# Default: patch

set -e

VERSION_FILE="Version.json"
INCREMENT_TYPE="${1:-patch}"

# Check if Version.json exists
if [ ! -f "$VERSION_FILE" ]; then
    echo "Error: $VERSION_FILE not found"
    exit 1
fi

# Read current version
current_version=$(grep -o '"version":[[:space:]]*"[^"]*"' "$VERSION_FILE" | grep -o '[0-9]*\.[0-9]*\.[0-9]*')

# Parse version components
IFS='.' read -r major minor patch <<< "$current_version"

# Increment based on type
case "$INCREMENT_TYPE" in
    major)
        major=$((major + 1))
        minor=0
        patch=0
        ;;
    minor)
        minor=$((minor + 1))
        patch=0
        ;;
    patch)
        patch=$((patch + 1))
        ;;
    *)
        echo "Error: Invalid increment type. Use: major, minor, or patch"
        exit 1
        ;;
esac

new_version="$major.$minor.$patch"

# Update Version.json with new version (preserving formatting)
sed -i '' "s/\"version\":[[:space:]]*\"[^\"]*\"/\"version\": \"$new_version\"/" "$VERSION_FILE"

echo "Version incremented ($INCREMENT_TYPE): $current_version -> $new_version"
