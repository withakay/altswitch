#!/bin/bash
# Interactive window activation script for MacWindowSwitch

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Find the CLI binary
CLI_DEBUG=".build/debug/mac-window-switch"
CLI_RELEASE=".build/release/mac-window-switch"

if [ -f "$CLI_RELEASE" ]; then
    CLI="$CLI_RELEASE"
elif [ -f "$CLI_DEBUG" ]; then
    CLI="$CLI_DEBUG"
else
    echo -e "${RED}Error: mac-window-switch binary not found${NC}"
    echo "Please run 'make build' first"
    exit 1
fi

echo -e "${GREEN}MacWindowSwitch - Interactive Window Activation${NC}"
echo ""
echo "Tip: Run 'make run-debug-app' to see available window IDs"
echo ""

# Prompt for Window ID
read -p "Enter Window ID: " WINDOW_ID

if [ -z "$WINDOW_ID" ]; then
    echo -e "${RED}Error: Window ID cannot be empty${NC}"
    exit 1
fi

# Validate that WINDOW_ID is a number
if ! [[ "$WINDOW_ID" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: Window ID must be a number${NC}"
    exit 1
fi

# Prompt for Process ID (required)
read -p "Enter Process ID: " PROCESS_ID

echo ""
echo -e "${YELLOW}Activating window...${NC}"

# Validate and build command
if [ -z "$PROCESS_ID" ]; then
    echo -e "${RED}Error: Process ID is required${NC}"
    echo "The activate command requires both window ID and process ID"
    exit 1
fi

# Validate that PROCESS_ID is a number
if ! [[ "$PROCESS_ID" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: Process ID must be a number${NC}"
    exit 1
fi

# Execute the command
if $CLI activate --window-id "$WINDOW_ID" --pid "$PROCESS_ID"; then
    echo -e "${GREEN}✓ Window activated successfully${NC}"
else
    echo -e "${RED}✗ Failed to activate window${NC}"
    exit 1
fi
