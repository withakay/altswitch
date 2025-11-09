#!/bin/bash

echo "=== AltSwitch Debug Capture ==="
echo "Watching debug output..."
echo "Trigger AltSwitch with Cmd+Shift+Space to see debug output"
echo ""

# Start AltSwitch in background and capture output
/Users/jack/Library/Developer/Xcode/DerivedData/AltSwitch-flwwxnnnknxeheeeqzpamkdggzqk/Build/Products/Debug/AltSwitch.app/Contents/MacOS/AltSwitch 2>&1 &

# Keep the script running to see output
wait