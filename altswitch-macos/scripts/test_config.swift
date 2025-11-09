#!/usr/bin/env swift

import Foundation

// Simple test to verify YAML serialization fix
let configPath = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent(".config/altswitch/settings.yaml")

if let data = try? Data(contentsOf: configPath),
  let content = String(data: data, encoding: .utf8)
{
  print("Current settings.yaml content:")
  print(content)
  print("---")
  print("Contains 'restrict_to_main_display':", content.contains("restrict_to_main_display"))
  print("Config file exists at:", configPath.path)
} else {
  print("Could not read config file at:", configPath.path)
}
