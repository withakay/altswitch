//
//  ConfigurationFileManager.swift
//  AltSwitch
//
//  File system utilities for configuration management
//

import Foundation

/// Utilities for managing configuration files and directories
final class ConfigurationFileManager: Sendable {

  // MARK: - Constants

  /// Default configuration directory name
  static let defaultConfigDirectoryName = "altswitch"

  /// Default configuration file name
  static let defaultConfigFileName = "settings.yaml"

  /// Backup file extension
  static let backupExtension = "backup"

  // MARK: - Default Paths

  /// Default configuration directory URL
  static var defaultConfigDirectoryURL: URL {
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    return
      homeDirectory
      .appendingPathComponent(".config")
      .appendingPathComponent(defaultConfigDirectoryName)
  }

  /// Default configuration file URL
  static var defaultConfigFileURL: URL {
    return defaultConfigDirectoryURL.appendingPathComponent(defaultConfigFileName)
  }

  // MARK: - Directory Management

  /// Create configuration directory if it doesn't exist
  /// - Parameter url: The directory URL to create
  /// - Throws: ConfigurationFileError if creation fails
  static func createDirectoryIfNeeded(at url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
      return
    }

    do {
      try FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: true,
        attributes: nil
      )
    } catch CocoaError.fileWriteNoPermission {
      throw ConfigurationFileError.permissionDenied
    } catch CocoaError.fileWriteVolumeReadOnly {
      throw ConfigurationFileError.diskReadOnly
    } catch {
      throw ConfigurationFileError.directoryCreationFailed(error.localizedDescription)
    }
  }

  /// Check if directory exists and is writable
  /// - Parameter url: The directory URL to check
  /// - Returns: True if directory exists and is writable
  static func isDirectoryWritable(at url: URL) -> Bool {
    guard FileManager.default.fileExists(atPath: url.path) else {
      return false
    }

    return FileManager.default.isWritableFile(atPath: url.path)
  }

  /// Get directory size in bytes
  /// - Parameter url: The directory URL
  /// - Returns: Size in bytes, or 0 if calculation fails
  static func getDirectorySize(at url: URL) -> Int64 {
    guard
      let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.fileSizeKey],
        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
      )
    else {
      return 0
    }

    var totalSize: Int64 = 0

    for case let fileURL as URL in enumerator {
      do {
        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        totalSize += Int64(resourceValues.fileSize ?? 0)
      } catch {
        continue
      }
    }

    return totalSize
  }

  // MARK: - File Management

  /// Check if file exists
  /// - Parameter url: The file URL to check
  /// - Returns: True if file exists
  static func fileExists(at url: URL) -> Bool {
    return FileManager.default.fileExists(atPath: url.path)
  }

  /// Check if file is readable
  /// - Parameter url: The file URL to check
  /// - Returns: True if file is readable
  static func isFileReadable(at url: URL) -> Bool {
    return FileManager.default.isReadableFile(atPath: url.path)
  }

  /// Check if file is writable
  /// - Parameter url: The file URL to check
  /// - Returns: True if file is writable
  static func isFileWritable(at url: URL) -> Bool {
    return FileManager.default.isWritableFile(atPath: url.path)
  }

  /// Get file size in bytes
  /// - Parameter url: The file URL
  /// - Returns: Size in bytes, or 0 if file doesn't exist
  static func getFileSize(at url: URL) -> Int64 {
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      return attributes[.size] as? Int64 ?? 0
    } catch {
      return 0
    }
  }

  /// Get file modification date
  /// - Parameter url: The file URL
  /// - Returns: Modification date, or nil if file doesn't exist
  static func getFileModificationDate(at url: URL) -> Date? {
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      return attributes[.modificationDate] as? Date
    } catch {
      return nil
    }
  }

  /// Read file as Data
  /// - Parameter url: The file URL to read
  /// - Returns: File contents as Data
  /// - Throws: ConfigurationFileError if reading fails
  static func readFile(at url: URL) throws -> Data {
    do {
      return try Data(contentsOf: url)
    } catch CocoaError.fileReadNoPermission {
      throw ConfigurationFileError.permissionDenied
    } catch CocoaError.fileReadNoSuchFile {
      throw ConfigurationFileError.fileNotFound
    } catch {
      throw ConfigurationFileError.readFailed(error.localizedDescription)
    }
  }

  /// Write data to file atomically
  /// - Parameters:
  ///   - data: The data to write
  ///   - url: The file URL to write to
  /// - Throws: ConfigurationFileError if writing fails
  static func writeFile(data: Data, to url: URL) throws {
    do {
      // Ensure parent directory exists
      try createDirectoryIfNeeded(at: url.deletingLastPathComponent())

      // Write atomically
      try data.write(to: url, options: .atomic)
    } catch CocoaError.fileWriteNoPermission {
      throw ConfigurationFileError.permissionDenied
    } catch CocoaError.fileWriteVolumeReadOnly {
      throw ConfigurationFileError.diskReadOnly
    } catch CocoaError.fileWriteFileExists {
      throw ConfigurationFileError.diskFull
    } catch let error as ConfigurationFileError {
      throw error
    } catch {
      throw ConfigurationFileError.writeFailed(error.localizedDescription)
    }
  }

  /// Delete file
  /// - Parameter url: The file URL to delete
  /// - Throws: ConfigurationFileError if deletion fails
  static func deleteFile(at url: URL) throws {
    guard fileExists(at: url) else {
      return
    }

    do {
      try FileManager.default.removeItem(at: url)
    } catch CocoaError.fileWriteNoPermission {
      throw ConfigurationFileError.permissionDenied
    } catch {
      throw ConfigurationFileError.deleteFailed(error.localizedDescription)
    }
  }

  // MARK: - Backup Management

  /// Create a backup of the configuration file
  /// - Parameters:
  ///   - sourceURL: The source file to backup
  ///   - includeTimestamp: Whether to include timestamp in backup name
  /// - Returns: URL of the created backup file
  /// - Throws: ConfigurationFileError if backup creation fails
  static func createBackup(of sourceURL: URL, includeTimestamp: Bool = true) throws -> URL {
    guard fileExists(at: sourceURL) else {
      throw ConfigurationFileError.fileNotFound
    }

    let backupURL: URL
    if includeTimestamp {
      let timestamp = Int(Date().timeIntervalSince1970)
      backupURL = sourceURL.appendingPathExtension("\(backupExtension).\(timestamp)")
    } else {
      backupURL = sourceURL.appendingPathExtension(backupExtension)
    }

    do {
      try FileManager.default.copyItem(at: sourceURL, to: backupURL)
      return backupURL
    } catch CocoaError.fileWriteNoPermission {
      throw ConfigurationFileError.permissionDenied
    } catch CocoaError.fileWriteVolumeReadOnly {
      throw ConfigurationFileError.diskReadOnly
    } catch {
      throw ConfigurationFileError.backupFailed(error.localizedDescription)
    }
  }

  /// Restore from backup
  /// - Parameters:
  ///   - backupURL: The backup file to restore from
  ///   - targetURL: The target file to restore to
  /// - Throws: ConfigurationFileError if restoration fails
  static func restoreFromBackup(from backupURL: URL, to targetURL: URL) throws {
    guard fileExists(at: backupURL) else {
      throw ConfigurationFileError.fileNotFound
    }

    do {
      // Remove target file if it exists
      if fileExists(at: targetURL) {
        try FileManager.default.removeItem(at: targetURL)
      }

      // Copy backup to target
      try FileManager.default.copyItem(at: backupURL, to: targetURL)
    } catch CocoaError.fileWriteNoPermission {
      throw ConfigurationFileError.permissionDenied
    } catch {
      throw ConfigurationFileError.restoreFailed(error.localizedDescription)
    }
  }

  /// List all backup files for a given configuration file
  /// - Parameter configURL: The configuration file URL
  /// - Returns: Array of backup file URLs, sorted by creation date (newest first)
  static func listBackups(for configURL: URL) -> [URL] {
    let directory = configURL.deletingLastPathComponent()
    let baseName = configURL.deletingPathExtension().lastPathComponent
    let baseExtension = configURL.pathExtension

    guard
      let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.creationDateKey],
        options: [.skipsSubdirectoryDescendants]
      )
    else {
      return []
    }

    var backups: [(URL, Date)] = []

    for case let fileURL as URL in enumerator {
      let fileName = fileURL.lastPathComponent
      let expectedPrefix = "\(baseName).\(baseExtension).\(backupExtension)"

      if fileName.hasPrefix(expectedPrefix) {
        let creationDate = getFileModificationDate(at: fileURL) ?? Date.distantPast
        backups.append((fileURL, creationDate))
      }
    }

    // Sort by creation date (newest first)
    backups.sort { $0.1 > $1.1 }

    return backups.map { $0.0 }
  }

  /// Clean up old backup files, keeping only the specified number
  /// - Parameters:
  ///   - configURL: The configuration file URL
  ///   - keepCount: Number of backup files to keep (default: 5)
  /// - Throws: ConfigurationFileError if cleanup fails
  static func cleanupOldBackups(for configURL: URL, keepCount: Int = 5) throws {
    let backups = listBackups(for: configURL)

    // Remove excess backups
    if backups.count > keepCount {
      let backupsToRemove = Array(backups.dropFirst(keepCount))

      for backup in backupsToRemove {
        do {
          try FileManager.default.removeItem(at: backup)
        } catch {
          // Continue with other backups even if one fails
          continue
        }
      }
    }
  }

  // MARK: - Cross-Platform Support

  /// Get the appropriate configuration directory for the current platform
  /// - Returns: Configuration directory URL
  static func getConfigDirectoryForPlatform() -> URL {
    #if os(macOS)
      return defaultConfigDirectoryURL
    #elseif os(iOS)
      // iOS uses app's Documents directory
      let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        .first!
      return documentsPath.appendingPathComponent(defaultConfigDirectoryName)
    #else
      // Fallback for other platforms
      return defaultConfigDirectoryURL
    #endif
  }

  /// Get temporary directory for configuration operations
  /// - Returns: Temporary directory URL
  static func getTemporaryDirectory() -> URL {
    return FileManager.default.temporaryDirectory.appendingPathComponent(defaultConfigDirectoryName)
  }
}

// MARK: - Error Types

/// Errors that can occur during configuration file operations
enum ConfigurationFileError: Error, LocalizedError, Sendable {
  case fileNotFound
  case permissionDenied
  case diskReadOnly
  case diskFull
  case directoryCreationFailed(String)
  case readFailed(String)
  case writeFailed(String)
  case deleteFailed(String)
  case backupFailed(String)
  case restoreFailed(String)

  var errorDescription: String? {
    switch self {
    case .fileNotFound:
      return "Configuration file not found"
    case .permissionDenied:
      return "Permission denied: cannot access configuration file"
    case .diskReadOnly:
      return "Disk is read-only: cannot write configuration file"
    case .diskFull:
      return "Disk is full: cannot write configuration file"
    case .directoryCreationFailed(let details):
      return "Failed to create configuration directory: \(details)"
    case .readFailed(let details):
      return "Failed to read configuration file: \(details)"
    case .writeFailed(let details):
      return "Failed to write configuration file: \(details)"
    case .deleteFailed(let details):
      return "Failed to delete configuration file: \(details)"
    case .backupFailed(let details):
      return "Failed to create backup: \(details)"
    case .restoreFailed(let details):
      return "Failed to restore from backup: \(details)"
    }
  }
}

// MARK: - Configuration File Validation

extension ConfigurationFileManager {
  /// Validate configuration file format and permissions
  /// - Parameter url: The configuration file URL to validate
  /// - Returns: Validation result with any issues found
  static func validateConfigurationFile(at url: URL) -> ConfigurationFileValidation {
    var issues: [String] = []
    var isValid = true

    // Check if file exists
    guard fileExists(at: url) else {
      return ConfigurationFileValidation(isValid: false, issues: ["File does not exist"])
    }

    // Check permissions
    if !isFileReadable(at: url) {
      issues.append("File is not readable")
      isValid = false
    }

    if !isFileWritable(at: url) {
      issues.append("File is not writable")
      isValid = false
    }

    // Check file size (reasonable limits)
    let fileSize = getFileSize(at: url)
    if fileSize == 0 {
      issues.append("File is empty")
      isValid = false
    } else if fileSize > 1024 * 1024 {  // 1MB limit
      issues.append("File is too large (> 1MB)")
      isValid = false
    }

    // Check directory permissions
    let directory = url.deletingLastPathComponent()
    if !isDirectoryWritable(at: directory) {
      issues.append("Parent directory is not writable")
      isValid = false
    }

    return ConfigurationFileValidation(isValid: isValid, issues: issues)
  }
}

/// Result of configuration file validation
struct ConfigurationFileValidation: Sendable {
  let isValid: Bool
  let issues: [String]

  var hasIssues: Bool {
    return !issues.isEmpty
  }
}
