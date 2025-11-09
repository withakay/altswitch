//
//  SkyLight.framework.swift
//  AltSwitch
//
//  Private CoreGraphics/SkyLight APIs for Spaces management
//  NOTE: Window activation APIs have been moved to MacWindowSwitch package
//

import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - Private CoreGraphics Types

typealias CGSSpaceID = Int
typealias CGSConnectionID = UInt
typealias ScreenUuid = CFString

// MARK: - Private CoreGraphics Functions for Space Management

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ connection: CGSConnectionID) -> CFArray

@_silgen_name("CGSManagedDisplayGetCurrentSpace")
func CGSManagedDisplayGetCurrentSpace(_ cid: CGSConnectionID, _ displayUuid: ScreenUuid) -> CGSSpaceID

@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(_ connection: CGSConnectionID, _ mask: CGSSpaceMask.RawValue, _ windowIDs: CFArray) -> CFArray

@_silgen_name("CGSCopyWindowsWithOptionsAndTags")
func CGSCopyWindowsWithOptionsAndTags(
  _ cid: CGSConnectionID,
  _ owner: Int,
  _ spaces: CFArray,
  _ options: Int,
  _ setTags: UnsafeMutablePointer<Int>,
  _ clearTags: UnsafeMutablePointer<Int>
) -> CFArray

@_silgen_name("CGSCopyActiveMenuBarDisplayIdentifier")
func CGSCopyActiveMenuBarDisplayIdentifier(_ cid: CGSConnectionID) -> ScreenUuid

// MARK: - CGSSpaceMask

enum CGSSpaceMask: Int {
  case current = 5  // Only current space
  case other = 6    // Other spaces
  case all = 7      // All spaces (including "on all spaces" windows)
}

// MARK: - CGSCopyWindowsOptions

struct CGSCopyWindowsOptions: OptionSet {
  let rawValue: Int

  static let screenSaverLevel1000 = CGSCopyWindowsOptions(rawValue: 1 << 0)
  static let invisible1 = CGSCopyWindowsOptions(rawValue: 1 << 3)
  static let invisible2 = CGSCopyWindowsOptions(rawValue: 1 << 4)
}

// MARK: - CGSCopyWindowsTags

struct CGSCopyWindowsTags: OptionSet {
  let rawValue: Int
}

// MARK: - Global Connection ID

let CGS_CONNECTION = CGSMainConnectionID()
