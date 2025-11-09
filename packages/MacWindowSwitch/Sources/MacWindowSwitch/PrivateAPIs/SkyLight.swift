//
//  SkyLight.swift
//  MacWindowSwitch
//
//  Private API declarations from SkyLight.framework
//  Ported from alt-tab-macos: https://github.com/lwouis/alt-tab-macos
//
//  SkyLight is the private framework in charge of interacting with the Window Server.
//  Location: Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/PrivateFrameworks/SkyLight.framework
//

import CoreGraphics
import Foundation

// MARK: - SkyLight Private APIs

/// Enum defining modes for _SLPSSetFrontProcessWithOptions
enum SLPSMode: UInt32 {
    case allWindows = 0x100
    case userGenerated = 0x200
    case noWindows = 0x400
}

/// Focuses the front process and activates a specific window
///
/// This is the primary API for cross-space window activation. It automatically
/// handles space switching when the target window is on a different space.
///
/// - Parameters:
///   - psn: Process Serial Number of the target process
///   - wid: CGWindowID of the window to activate
///   - mode: Activation mode (typically .userGenerated)
/// - Returns: CGError (kCGErrorSuccess on success)
///
/// **Private API Warning:**
/// - Available: macOS 10.12+
/// - Status: Private, may change in future macOS versions
/// - Risk: Medium - Stable since macOS 10.12, widely used by window managers
/// - Fallback: AXUIElement public API (doesn't support cross-space switching)
@_silgen_name("_SLPSSetFrontProcessWithOptions")
@discardableResult
func _SLPSSetFrontProcessWithOptions(
    _ psn: UnsafeMutablePointer<ProcessSerialNumber>,
    _ wid: CGWindowID,
    _ mode: SLPSMode.RawValue
) -> CGError

/// Sends low-level event bytes to the Window Server
///
/// This API is used to make a window "key" within its application (frontmost window
/// of the app). It sends a specially-formatted byte array to the window server.
///
/// - Parameters:
///   - psn: Process Serial Number of the target process
///   - bytes: Pointer to byte array containing window server commands
/// - Returns: CGError (kCGErrorSuccess on success)
///
/// **Private API Warning:**
/// - Available: macOS 10.12+
/// - Status: Private, may change in future macOS versions
/// - Risk: High - Low-level byte protocol may be unstable
/// - Context: https://github.com/Hammerspoon/hammerspoon/issues/370#issuecomment-545545468
/// - Fallback: None - this is required for making window key in some cases
@_silgen_name("SLPSPostEventRecordTo")
@discardableResult
func SLPSPostEventRecordTo(
    _ psn: UnsafeMutablePointer<ProcessSerialNumber>,
    _ bytes: UnsafeMutablePointer<UInt8>
) -> CGError
