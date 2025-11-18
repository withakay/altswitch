#!/bin/bash
# Notarize AltSwitch.app and staple the ticket
# This script is called after building but before packaging

set -e

# Configuration
APP_NAME="AltSwitch.app"
DIST_DIR="dist"
TEAM_ID="576985M4ZN"
KEYCHAIN_PROFILE="notarytool-altswitch"

# Paths
APP_PATH="$DIST_DIR/$APP_NAME"

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

echo_info "Checking notarization prerequisites..."

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo_error "App bundle not found: $APP_PATH"
    echo "Run 'make build-release' first"
    exit 1
fi

# Check for Developer ID certificate
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo_error "Developer ID Application certificate not found!"
    echo ""
    echo "Please install it via:"
    echo "  Xcode → Settings → Accounts → Manage Certificates"
    echo "  Or download from: https://developer.apple.com/account/resources/certificates/list"
    echo ""
    echo "After installing, you may need to restart Xcode/Terminal."
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
    echo "Notes:"
    echo "  - Use your Apple ID email"
    echo "  - Generate an app-specific password at: https://appleid.apple.com/account/manage"
    echo "  - The password format is: xxxx-xxxx-xxxx-xxxx (4 groups of 4 characters)"
    echo ""
    exit 1
fi
echo_success "Notarization credentials configured"

###############################################################################
# Step 1: Verify Code Signature
###############################################################################

echo_info "Verifying code signature..."

if ! codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1 | grep -q "satisfies"; then
    echo_error "Code signature verification failed!"
    echo ""
    echo "The app may not be properly signed with Developer ID."
    echo "Check Xcode project signing settings."
    exit 1
fi
echo_success "Code signature valid"

# Display signing info
SIGNING_IDENTITY=$(codesign -dvv "$APP_PATH" 2>&1 | grep "Authority=Developer ID Application" | head -1)
echo_info "Signed with: ${SIGNING_IDENTITY#*Authority=}"

###############################################################################
# Step 2: Create ZIP for Notarization
###############################################################################

echo_info "Creating ZIP archive for notarization..."

# Create a temporary ZIP for submission
TEMP_ZIP="$DIST_DIR/AltSwitch-temp.zip"
rm -f "$TEMP_ZIP"

# Use ditto to preserve code signatures
cd "$DIST_DIR"
ditto -c -k --keepParent "$APP_NAME" "$(basename "$TEMP_ZIP")"
cd - > /dev/null

if [ ! -f "$TEMP_ZIP" ]; then
    echo_error "Failed to create ZIP archive"
    exit 1
fi
echo_success "ZIP created: $TEMP_ZIP"

###############################################################################
# Step 3: Submit for Notarization
###############################################################################

echo_info "Submitting to Apple for notarization..."
echo_info "This may take 1-5 minutes, please wait..."
echo ""

NOTARIZATION_OUTPUT=$(xcrun notarytool submit "$TEMP_ZIP" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait 2>&1)

echo "$NOTARIZATION_OUTPUT"
echo ""

# Clean up temp ZIP
rm -f "$TEMP_ZIP"

if echo "$NOTARIZATION_OUTPUT" | grep -q "status: Accepted"; then
    echo_success "Notarization accepted!"
else
    echo_error "Notarization failed!"
    echo ""

    # Extract submission ID for log retrieval
    SUBMISSION_ID=$(echo "$NOTARIZATION_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')

    if [ -n "$SUBMISSION_ID" ]; then
        echo_info "Fetching detailed log..."
        echo ""
        xcrun notarytool log "$SUBMISSION_ID" \
            --keychain-profile "$KEYCHAIN_PROFILE"
    fi
    exit 1
fi

###############################################################################
# Step 4: Staple Notarization Ticket
###############################################################################

echo_info "Stapling notarization ticket to app bundle..."

if ! xcrun stapler staple "$APP_PATH" 2>&1; then
    echo_error "Stapling failed!"
    echo ""
    echo "The app is notarized but the ticket couldn't be stapled."
    echo "Users will need an internet connection to verify."
    exit 1
fi
echo_success "Notarization ticket stapled"

###############################################################################
# Step 5: Verify Notarization
###############################################################################

echo_info "Verifying notarization..."

if ! xcrun stapler validate "$APP_PATH" 2>&1 | grep -q "The validate action worked"; then
    echo_error "Stapler validation failed!"
    exit 1
fi
echo_success "Stapler validation passed"

if ! spctl -a -vv "$APP_PATH" 2>&1 | grep -q "accepted"; then
    echo_error "Gatekeeper verification failed!"
    exit 1
fi
echo_success "Gatekeeper verification passed"

###############################################################################
# Done!
###############################################################################

echo ""
echo_success "✅ App successfully notarized and stapled!"
echo ""
echo "The app at $APP_PATH is now:"
echo "  ✓ Code-signed with Developer ID"
echo "  ✓ Notarized by Apple"
echo "  ✓ Ticket stapled (works offline)"
echo "  ✓ Gatekeeper approved"
echo ""
echo "DMG/ZIP packages will inherit this notarization."
