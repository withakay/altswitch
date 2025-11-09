#!/bin/bash

# MacWindowDiscovery CLI - Manual Verification Test Script
#
# This script automatically opens applications and runs CLI commands
# to verify window detection is working correctly.
#
# Usage: ./test-cli-manual.sh

set -e  # Exit on error

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test results
PASSED=0
FAILED=0
TOTAL=0

# CLI path
CLI_PATH=".build/debug/mac-window-discovery"

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

wait_for_enter() {
    echo ""
    echo -e "${YELLOW}Press [Enter] to continue...${NC}"
    read -r
}

verify_result() {
    local test_name="$1"
    TOTAL=$((TOTAL + 1))

    echo ""
    echo -e "${YELLOW}Did this test PASS? [y/n]:${NC} "
    read -r result

    if [[ "$result" =~ ^[Yy]$ ]]; then
        PASSED=$((PASSED + 1))
        print_success "Test passed: $test_name"
    else
        FAILED=$((FAILED + 1))
        print_error "Test failed: $test_name"
    fi
}

open_app() {
    local app_name="$1"
    print_info "Opening $app_name..."
    open -a "$app_name"
    sleep 2
}

close_app() {
    local app_name="$1"
    osascript -e "quit app \"$app_name\"" 2>/dev/null || true
}

close_finder_windows() {
    osascript -e 'tell application "Finder" to close every window' 2>/dev/null || true
}

run_cli() {
    echo ""
    echo -e "${BLUE}RUNNING:${NC} $CLI_PATH $*"
    echo ""
    "$CLI_PATH" "$@"
    echo ""
}

# Main script
main() {
    clear
    print_header "MacWindowDiscovery CLI - Manual Verification Tests"

    echo "This script will:"
    echo "  1. Build the CLI tool"
    echo "  2. Open test applications automatically"
    echo "  3. Run CLI commands to detect windows"
    echo "  4. Ask you to verify the results"
    echo "  5. Clean up and show a summary"

    wait_for_enter

    # ========================================
    # TEST 0: Build CLI
    # ========================================
    print_header "TEST 0: Building CLI Tool"

    print_info "Building MacWindowDiscovery CLI..."
    if swift build 2>&1 | tail -5; then
        print_success "CLI built successfully"
    else
        print_error "Failed to build CLI"
        exit 1
    fi

    if [ ! -f "$CLI_PATH" ]; then
        print_error "CLI binary not found at $CLI_PATH"
        exit 1
    fi

    wait_for_enter

    # ========================================
    # TEST 1: Pre-flight Check
    # ========================================
    print_header "TEST 1: Pre-flight Check"

    print_info "Checking CLI version..."
    run_cli --version

    print_info "Checking permissions..."
    run_cli permissions

    echo "VERIFY:"
    echo "  1. CLI version shown"
    echo "  2. Accessibility permission: GRANTED"

    verify_result "Pre-flight Check"

    # ========================================
    # TEST 2: Single Window Detection
    # ========================================
    print_header "TEST 2: Single Window Detection"

    print_info "Opening TextEdit with 1 window..."
    open_app "TextEdit"

    wait_for_enter

    run_cli list --app com.apple.TextEdit --format table

    echo "VERIFY:"
    echo "  1. Exactly 1 TextEdit window shown"
    echo "  2. Title is 'Untitled' or similar"
    echo "  3. Bounds are reasonable (width/height > 0)"

    verify_result "Single Window Detection"

    # ========================================
    # TEST 3: Multi-Window Detection
    # ========================================
    print_header "TEST 3: Multi-Window Detection (TextEdit)"

    print_info "Opening 2 more TextEdit windows..."
    osascript -e 'tell application "TextEdit" to make new document'
    sleep 1
    osascript -e 'tell application "TextEdit" to make new document'
    sleep 1

    wait_for_enter

    run_cli list --app com.apple.TextEdit --format table

    echo "VERIFY:"
    echo "  1. See 3 TextEdit windows"
    echo "  2. Each has different window ID"
    echo "  3. Titles may be Untitled, Untitled 2, Untitled 3"

    verify_result "Multi-Window Detection"

    # ========================================
    # TEST 4: Multiple Applications
    # ========================================
    print_header "TEST 4: Multiple Applications Detection"

    print_info "Opening Safari, Notes, Calculator, and Finder..."
    open_app "Safari"
    open_app "Notes"
    open_app "Calculator"

    # Open Finder windows
    print_info "Opening Finder windows..."
    osascript -e 'tell application "Finder"
        activate
        make new Finder window
        set target of front window to (path to desktop folder)
    end tell'
    sleep 1

    wait_for_enter

    run_cli list --format compact

    echo "VERIFY:"
    echo "  1. See TextEdit (3 windows)"
    echo "  2. See Safari (at least 1 window)"
    echo "  3. See Notes (1 window)"
    echo "  4. See Calculator (1 window)"
    echo "  5. See Finder (at least 1 window)"

    verify_result "Multiple Applications"

    # ========================================
    # TEST 5: Finder Multi-Window
    # ========================================
    print_header "TEST 5: Finder Multi-Window Detection"

    print_info "Opening more Finder windows..."
    osascript -e 'tell application "Finder"
        make new Finder window
        set target of front window to (path to documents folder)
    end tell'
    sleep 1
    osascript -e 'tell application "Finder"
        make new Finder window
        set target of front window to (path to downloads folder)
    end tell'
    sleep 1

    wait_for_enter

    run_cli list --app com.apple.finder --format table

    echo "VERIFY:"
    echo "  1. See at least 3 Finder windows"
    echo "  2. Titles include folder names (Desktop, Documents, Downloads)"
    echo "  3. All windows from com.apple.finder"

    verify_result "Finder Multi-Window"

    # ========================================
    # TEST 6: JSON Output
    # ========================================
    print_header "TEST 6: JSON Output Format"

    wait_for_enter

    run_cli list --app com.apple.TextEdit --format json

    echo "VERIFY:"
    echo "  1. Output is valid JSON (starts with [ or {)"
    echo "  2. Contains fields: id, title, bounds, alpha, bundleIdentifier"
    echo "  3. JSON is properly formatted"

    verify_result "JSON Output"

    # ========================================
    # TEST 7: App-Specific Query
    # ========================================
    print_header "TEST 7: App-Specific Query"

    wait_for_enter

    run_cli app com.apple.Safari

    echo "VERIFY:"
    echo "  1. Shows only Safari windows"
    echo "  2. Detailed information displayed"
    echo "  3. Window count matches Safari windows open"

    verify_result "App-Specific Query"

    # ========================================
    # TEST 8: Hidden Window Detection
    # ========================================
    print_header "TEST 8: Hidden Window Detection"

    print_info "Hiding Calculator (⌘H)..."
    osascript -e 'tell application "System Events" to tell process "Calculator" to set visible to false'
    sleep 1

    wait_for_enter

    run_cli list --include-hidden --app com.apple.calculator --format table

    echo "VERIFY:"
    echo "  1. Calculator window still shown"
    echo "  2. 'Hidden' field or flag indicates hidden state"
    echo "  3. Window details still accurate"

    verify_result "Hidden Window Detection"

    # ========================================
    # TEST 9: Minimized Window Detection
    # ========================================
    print_header "TEST 9: Minimized Window Detection"

    print_info "Minimizing a Safari window..."
    osascript -e 'tell application "Safari" to set miniaturized of window 1 to true' 2>/dev/null || true
    sleep 1

    wait_for_enter

    run_cli list --include-minimized --app com.apple.Safari --format table

    echo "VERIFY:"
    echo "  1. See minimized Safari window"
    echo "  2. 'Minimized' field shows true"
    echo "  3. Other Safari windows (if any) also shown"

    verify_result "Minimized Window Detection"

    # ========================================
    # TEST 10: Size Filtering
    # ========================================
    print_header "TEST 10: Window Size Filtering"

    wait_for_enter

    run_cli list --min-width 500 --min-height 400 --format compact

    echo "VERIFY:"
    echo "  1. Only large windows shown (>= 500x400)"
    echo "  2. Small utility windows filtered out"
    echo "  3. Major app windows visible (TextEdit, Safari, etc.)"

    verify_result "Size Filtering"

    # ========================================
    # Cleanup
    # ========================================
    print_header "CLEANUP"

    print_info "Closing test applications..."
    close_app "TextEdit"
    close_app "Safari"
    close_app "Notes"
    close_app "Calculator"
    close_finder_windows

    print_success "Cleanup complete"

    # ========================================
    # Summary
    # ========================================
    print_header "TEST SUMMARY"

    echo ""
    echo "Total Tests: $TOTAL"
    echo -e "${GREEN}Passed: $PASSED ✓${NC}"
    echo -e "${RED}Failed: $FAILED ✗${NC}"
    echo ""

    if [ $FAILED -eq 0 ]; then
        print_success "ALL TESTS PASSED! 🎉"
        echo ""
        echo "The MacWindowDiscovery CLI is working correctly."
    else
        print_error "Some tests failed. Review the output above."
        echo ""
        echo "Failed tests may indicate:"
        echo "  - CLI bugs in window detection"
        echo "  - Missing accessibility permissions"
        echo "  - App-specific detection issues"
    fi

    # Calculate pass rate
    if [ $TOTAL -gt 0 ]; then
        PASS_RATE=$((PASSED * 100 / TOTAL))
        echo ""
        echo "Pass Rate: ${PASS_RATE}%"
    fi

    echo ""
}

# Run main function
main
