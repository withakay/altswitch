#!/usr/bin/env python3
"""
List all windows with their IDs and PIDs for testing MacWindowSwitch.

Usage:
    python3 list-windows.py [--app APP_NAME]

Example:
    python3 list-windows.py
    python3 list-windows.py --app Safari
"""

import sys
import argparse

try:
    from Quartz import (
        CGWindowListCopyWindowInfo,
        kCGWindowListOptionAll,
        kCGNullWindowID
    )
except ImportError:
    print("Error: Quartz module not available.")
    print("This script requires PyObjC: pip3 install pyobjc-framework-Quartz")
    sys.exit(1)


def list_windows(app_filter=None):
    """List all windows with their details."""
    windows = CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID)

    # Header
    print(f"{'App':<25s} {'Window Title':<40s} {'ID':>8s} {'PID':>7s}")
    print("-" * 85)

    count = 0
    for w in windows:
        app = w.get('kCGWindowOwnerName', '')
        title = w.get('kCGWindowName', 'Untitled')
        wid = w.get('kCGWindowNumber', 0)
        pid = w.get('kCGWindowOwnerPID', 0)

        # Filter by app name if specified
        if app_filter and app_filter.lower() not in app.lower():
            continue

        # Skip windows without proper info
        if not app or wid == 0:
            continue

        # Truncate long titles
        if len(title) > 40:
            title = title[:37] + "..."

        print(f"{app:<25s} {title:<40s} {wid:8d} {pid:7d}")
        count += 1

    print(f"\nTotal windows: {count}")

    # Print example command
    if count > 0:
        print("\nExample usage:")
        print("  mac-window-switch activate --window-id <ID> --pid <PID>")


def main():
    parser = argparse.ArgumentParser(
        description="List macOS windows for testing MacWindowSwitch"
    )
    parser.add_argument(
        '--app',
        type=str,
        help='Filter by application name (case-insensitive)'
    )
    args = parser.parse_args()

    list_windows(app_filter=args.app)


if __name__ == '__main__':
    main()
