#!/bin/bash

echo "Testing AltSwitch app..."
echo "========================"

# Check if app is running
if pgrep -f AltSwitch > /dev/null; then
    echo "✓ App is running"
else
    echo "✗ App is not running"
    echo "Starting app..."
    open /Users/jack/Code/withakay/mac-apps/altswitch/AltSwitch/build/Build/Products/Debug/AltSwitch.app
    sleep 2
fi

# Check for menu bar icon
echo ""
echo "Check the menu bar for the command square (⌘) icon"
echo "Click on it to see the menu options:"
echo "- Show AltSwitch (Cmd+Space)"
echo "- Settings... (Cmd+,)"
echo "- About AltSwitch"
echo "- Quit (Cmd+Q)"
echo ""
echo "Try pressing Cmd+Space to toggle the app switcher window"
echo ""

# Check process info
echo "Process info:"
ps aux | grep -i altswitch | grep -v grep | awk '{print "  PID:", $2, "CPU:", $3"%", "MEM:", $4"%"}'

echo ""
echo "Test completed. The app should be running without errors."
echo "========================"