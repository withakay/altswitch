//
//  HIServices.swift
//  MacWindowSwitch
//
//  Private API declarations from ApplicationServices.HIServices.framework
//  Ported from alt-tab-macos: https://github.com/lwouis/alt-tab-macos
//

import Foundation

// MARK: - HIServices Private APIs

/// Converts a process ID (pid_t) to a Process Serial Number
///
/// Process Serial Numbers are deprecated but still required by some private APIs
/// like _SLPSSetFrontProcessWithOptions and SLPSPostEventRecordTo.
///
/// - Parameters:
///   - pid: Process ID of the target process
///   - psn: Output parameter for the Process Serial Number
/// - Returns: OSStatus (noErr on success)
///
/// **Private API Warning:**
/// - Available: macOS 10.9+ (officially deprecated in 10.9, but still available)
/// - Status: Deprecated public API, now private
/// - Risk: Medium - Has been stable since macOS 10.9
/// - Fallback: None - ProcessSerialNumber is required for SLPS* APIs
/// - Note: This function was officially removed from the public API in macOS 10.9
///         but remains available as a private API
@_silgen_name("GetProcessForPID")
@discardableResult
func GetProcessForPID(
    _ pid: pid_t,
    _ psn: UnsafeMutablePointer<ProcessSerialNumber>
) -> OSStatus
