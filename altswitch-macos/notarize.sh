#!/bin/bash

###############################################################################
# AltSwitch Notarization Script
#
# This script automates the process of:
# 1. Building AltSwitch for release
# 2. Creating a DMG installer
# 3. Submitting for notarization
# 4. Stapling the notarization ticket
#
# Prerequisites:
# - Developer ID Application certificate installed
# - Notarization credentials configured (see setup below)
#
# Usage:
#   ./notarize.sh
#
###############################################################################

set -e  # Exit on error

# Configuration
APP_NAME="AltSwitch"
SCHEME="AltSwitch"
CONFIGURATION="Release"
TEAM_ID="576985M4ZN"
KEYCHAIN_PROFILE="notarytool-altswitch"

# Paths
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$HOME/Desktop/AltSwitch-Build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/Export"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
NOTARIZED_DMG_PATH="$BUILD_DIR/$APP_NAME-Notarized.dmg"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

echo_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

echo_error() {
    echo -e "${RED}✗ $1${NC}"
}

###############################################################################
# Step 0: Check Prerequisites
###############################################################################

echo_info "Checking prerequisites..."

# Check for Developer ID certificate
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo_error "Developer ID Application certificate not found!"
    echo "Please install it via Xcode → Settings → Accounts → Manage Certificates"
    echo "Or download from https://developer.apple.com/account/resources/certificates/list"
    exit 1
fi
echo_success "Developer ID certificate found"

# Check for notarization credentials
if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" &>/dev/null; then
    echo_error "Notarization credentials not configured!"
    echo ""
    echo "Please run the following command to set up credentials:"
    echo ""
    echo "  xcrun notarytool store-credentials \"$KEYCHAIN_PROFILE\" \\"
    echo "    --apple-id \"your-apple-id@example.com\" \\"
    echo "    --team-id \"$TEAM_ID\" \\"
    echo "    --password \"xxxx-xxxx-xxxx-xxxx\""
    echo ""
    echo "Get an app-specific password from: https://appleid.apple.com/account/manage"
    exit 1
fi
echo_success "Notarization credentials configured"

###############################################################################
# Step 1: Clean Build Directory
###############################################################################

echo_info "Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
echo_success "Build directory cleaned"

###############################################################################
# Step 2: Build and Archive
###############################################################################

echo_info "Building $APP_NAME for release..."
cd "$PROJECT_DIR"

xcodebuild clean \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    >/dev/null 2>&1

xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    | grep -E "▸|error:|warning:" || true

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo_error "Archive failed!"
    exit 1
fi
echo_success "Archive created: $ARCHIVE_PATH"

###############################################################################
# Step 3: Export Archive
###############################################################################

echo_info "Exporting archive..."

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$PROJECT_DIR/ExportOptions.plist" \
    | grep -E "▸|error:|warning:" || true

if [ ! -d "$EXPORT_PATH/$APP_NAME.app" ]; then
    echo_error "Export failed!"
    exit 1
fi
echo_success "App exported to: $EXPORT_PATH/$APP_NAME.app"

###############################################################################
# Step 4: Verify Code Signature
###############################################################################

echo_info "Verifying code signature..."

codesign --verify --deep --strict --verbose=2 "$EXPORT_PATH/$APP_NAME.app" 2>&1 | grep -E "satisfies"
if [ $? -ne 0 ]; then
    echo_error "Code signature verification failed!"
    exit 1
fi
echo_success "Code signature valid"

###############################################################################
# Step 5: Create DMG
###############################################################################

echo_info "Creating DMG installer..."

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$EXPORT_PATH/$APP_NAME.app" \
    -ov -format UDZO \
    "$DMG_PATH" \
    >/dev/null 2>&1

if [ ! -f "$DMG_PATH" ]; then
    echo_error "DMG creation failed!"
    exit 1
fi
echo_success "DMG created: $DMG_PATH"

###############################################################################
# Step 6: Submit for Notarization
###############################################################################

echo_info "Submitting to Apple for notarization..."
echo "This may take 1-5 minutes..."

NOTARIZATION_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait 2>&1)

echo "$NOTARIZATION_OUTPUT"

if echo "$NOTARIZATION_OUTPUT" | grep -q "status: Accepted"; then
    echo_success "Notarization accepted!"
else
    echo_error "Notarization failed!"

    # Extract submission ID for log retrieval
    SUBMISSION_ID=$(echo "$NOTARIZATION_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')

    if [ -n "$SUBMISSION_ID" ]; then
        echo_info "Fetching detailed log..."
        xcrun notarytool log "$SUBMISSION_ID" \
            --keychain-profile "$KEYCHAIN_PROFILE"
    fi
    exit 1
fi

###############################################################################
# Step 7: Staple Notarization Ticket
###############################################################################

echo_info "Stapling notarization ticket to DMG..."

xcrun stapler staple "$DMG_PATH"
if [ $? -ne 0 ]; then
    echo_error "Stapling failed!"
    exit 1
fi
echo_success "Notarization ticket stapled"

###############################################################################
# Step 8: Verify Notarization
###############################################################################

echo_info "Verifying notarization..."

xcrun stapler validate "$DMG_PATH"
if [ $? -ne 0 ]; then
    echo_error "Validation failed!"
    exit 1
fi

spctl -a -vv "$EXPORT_PATH/$APP_NAME.app" 2>&1 | grep -q "accepted"
if [ $? -ne 0 ]; then
    echo_error "Gatekeeper verification failed!"
    exit 1
fi
echo_success "Notarization verified"

###############################################################################
# Step 9: Rename to Notarized Version
###############################################################################

mv "$DMG_PATH" "$NOTARIZED_DMG_PATH"
echo_success "Final DMG: $NOTARIZED_DMG_PATH"

###############################################################################
# Done!
###############################################################################

echo ""
echo_success "✅ Notarization complete!"
echo ""
echo "Distribution-ready DMG:"
echo "  $NOTARIZED_DMG_PATH"
echo ""
echo "DMG size: $(du -h "$NOTARIZED_DMG_PATH" | awk '{print $1}')"
echo ""
echo "You can now distribute this DMG to users."
echo "Users can double-click to install without warnings."
