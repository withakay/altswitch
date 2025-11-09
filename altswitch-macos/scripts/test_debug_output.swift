#!/usr/bin/env swift

import Foundation

print("=== AltSwitch Debug Monitor ===")
print("Launch AltSwitch and trigger it with Cmd+Shift+Space")
print("Then check what the restrictToMainDisplay setting shows")
print()

// Simple input waiting
print("Press Enter when you've triggered AltSwitch...")
_ = readLine()

print("Check Console.app or run:")
print("log show --process AltSwitch --last 1m")
