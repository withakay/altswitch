//
//  DebugLogger.swift
//  AltSwitch
//
//  Simple file-based debug logger
//

import Foundation

/// Simple debug logger that writes to a file
enum DebugLogger {
  private static let logFileURL =
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
    .appendingPathComponent("AltSwitch_debug.log")
    ?? URL(fileURLWithPath: "/tmp/AltSwitch_debug.log")

  static func log(
    _ message: String, file: String = #file, function: String = #function, line: Int = #line
  ) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let fileName = URL(fileURLWithPath: file).lastPathComponent
    let logMessage = "[\(timestamp)] [\(fileName):\(line)] \(function): \(message)\n"

    // Also print to console
    print(logMessage)

    // Write to file
    if let data = logMessage.data(using: .utf8) {
      if FileManager.default.fileExists(atPath: logFileURL.path) {
        // Append to existing file
        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
          fileHandle.seekToEndOfFile()
          fileHandle.write(data)
          fileHandle.closeFile()
        }
      } else {
        // Create new file
        try? data.write(to: logFileURL)
      }
    }
  }

  static func clear() {
    try? FileManager.default.removeItem(at: logFileURL)
  }

  static func getLogPath() -> String {
    return logFileURL.path
  }
}
