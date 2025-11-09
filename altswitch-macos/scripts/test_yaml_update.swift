#!/usr/bin/env swift

import Foundation

// Test script to monitor YAML changes
let configPath = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent(".config/altswitch/settings.yaml")

func readConfig() -> String? {
  guard let data = try? Data(contentsOf: configPath),
    let content = String(data: data, encoding: .utf8)
  else {
    return nil
  }
  return content
}

print("=== Monitoring YAML Configuration Changes ===")
print("Config path:", configPath.path)
print()

// Initial read
if let initial = readConfig() {
  print("INITIAL CONFIG:")
  print(initial)
  print("Contains 'restrict_to_main_display':", initial.contains("restrict_to_main_display"))
  print()
} else {
  print("Could not read initial config")
}

// Monitor for changes
print("Monitoring for changes... (press Ctrl+C to stop)")
var lastContent = readConfig()

while true {
  Thread.sleep(forTimeInterval: 2.0)
  let currentContent = readConfig()

  if currentContent != lastContent {
    print("\n=== CONFIG CHANGED ===")
    if let content = currentContent {
      print(content)
      print("Contains 'restrict_to_main_display':", content.contains("restrict_to_main_display"))
    }
    print("========================\n")
    lastContent = currentContent
  }
}
