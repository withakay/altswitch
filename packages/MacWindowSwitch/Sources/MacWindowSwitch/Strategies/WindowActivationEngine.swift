//
//  WindowActivationEngine.swift
//  MacWindowSwitch
//
//  Core window activation logic ported from alt-tab-macos Window.swift
//  This file contains the faithful port of the proven activation approach
//

import ApplicationServices
import Foundation

/// Engine for activating windows using the three-strategy approach
///
/// This class implements the exact activation logic from alt-tab-macos,
/// which has been battle-tested across macOS versions and configurations.
///
/// **Activation Strategies (in order):**
/// 1. SkyLight: _SLPSSetFrontProcessWithOptions - Primary cross-space activation
/// 2. HIServices: SLPSPostEventRecordTo - Makes window key within app
/// 3. Accessibility: AXUIElement kAXRaiseAction - Public API fallback
///
/// **Threading:**
/// All activation operations execute on a dedicated background queue to avoid
/// blocking the main thread during potentially slow accessibility calls.
final class WindowActivationEngine {
    /// Activate a window by its CGWindowID using injected resolvers.
    /// If PID cannot be resolved, the activation is skipped.
    static func activate(windowID: CGWindowID, dependencies: ActivationDependencies? = nil) {
        ActivationQueue.shared.addActivationOperation {
            // Resolve PID via dependency or fallback to CGWindowList
            let resolvedPid: pid_t? = dependencies?.pidResolver(windowID) ?? {
                guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else { return nil }
                for entry in list {
                    if let wid = entry[kCGWindowNumber as String] as? CGWindowID, wid == windowID,
                       let pid = entry[kCGWindowOwnerPID as String] as? pid_t { return pid }
                }
                return nil
            }()
            guard let processID = resolvedPid else {
                NSLog("MacWindowSwitch: [Engine] ❌ No PID for window \(windowID)")
                return
            }

            // SkyLight focus + make key
            var psn = ProcessSerialNumber()
            guard GetProcessForPID(processID, &psn) == 0 else { return }
            _ = _SLPSSetFrontProcessWithOptions(&psn, windowID, SLPSMode.userGenerated.rawValue)
            makeKeyWindow(windowID: windowID, psn: &psn)

            // Optional AX finalize if available
            DispatchQueue.main.async {
                if let ax = dependencies?.axResolver(windowID) {
                    _ = AXUIElementPerformAction(ax, kAXRaiseAction as CFString)
                }
            }
        }
    }

    /// Activate a window by its CGWindowID and owner process ID
    ///
    /// This method implements the exact logic from alt-tab-macos Window.focus()
    /// (lines 192-203) with minimal modifications for standalone use.
    ///
    /// - Parameters:
    ///   - windowID: The CGWindowID of the window to activate
    ///   - processID: The process ID that owns the window
    ///
    /// **Behavior:**
    /// - Executes on background queue (non-blocking)
    /// - Automatically switches spaces if window is on different space
    /// - Makes window key within its application
    /// - Raises window using accessibility API
    /// - Fire-and-forget operation (matches alt-tab-macos behavior)
    static func activate(windowID: CGWindowID, processID: pid_t) {
        // Add to background queue exactly as alt-tab-macos does
        ActivationQueue.shared.addActivationOperation {
            NSLog("MacWindowSwitch: [Engine] Activation START - window \(windowID), pid \(processID)")

            // Get Process Serial Number from PID
            var psn = ProcessSerialNumber()
            let getPIDResult = GetProcessForPID(processID, &psn)
            NSLog("MacWindowSwitch: [Engine] GetProcessForPID result: \(getPIDResult)")
            guard getPIDResult == 0 else {
                NSLog("MacWindowSwitch: [Engine] ❌ GetProcessForPID failed with status \(getPIDResult)")
                return
            }

            // STRATEGY 1: SkyLight - Primary cross-space activation
            // This automatically handles:
            // - Switching to the window's space if different
            // - Bringing the app to front
            // - Cross-display activation
            let skylightResult = _SLPSSetFrontProcessWithOptions(&psn, windowID, SLPSMode.userGenerated.rawValue)
            NSLog("MacWindowSwitch: [Engine] _SLPSSetFrontProcessWithOptions result: \(skylightResult)")

            // STRATEGY 2: HIServices - Make window key within app
            // This ensures the specific window becomes the frontmost window
            // of its application (important for multi-window apps)
            NSLog("MacWindowSwitch: [Engine] Calling makeKeyWindow...")
            makeKeyWindow(windowID: windowID, psn: &psn)

            // STRATEGY 3: Accessibility - Raise specific window using public API
            // This is a fallback that works even if private APIs change
            NSLog("MacWindowSwitch: [Engine] Calling AX raise action on specific window...")
            let appElement = AXUIElementCreateApplication(processID)

            // Try to find the specific window and raise it
            var windowsRef: CFTypeRef?
            let copyResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
            if copyResult == .success, let windows = windowsRef as? [AXUIElement] {
                NSLog("MacWindowSwitch: [Engine] Found \(windows.count) AX windows")
                var foundMatch = false
                for (index, window) in windows.enumerated() {
                    var windowIDRef: CFTypeRef?
                    let idResult = AXUIElementCopyAttributeValue(window, "_AXWindowID" as CFString, &windowIDRef)
                    NSLog("MacWindowSwitch: [Engine] Window[\(index)] _AXWindowID lookup result: \(idResult.rawValue)")
                    if idResult == .success, let axWindowID = windowIDRef as? UInt32 {
                        NSLog("MacWindowSwitch: [Engine] Window[\(index)] has ID \(axWindowID) (looking for \(windowID))")
                        if axWindowID == windowID {
                            NSLog("MacWindowSwitch: [Engine] ✅ Found matching window at index \(index), raising...")
                            let raiseResult = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                            NSLog("MacWindowSwitch: [Engine] AX raise result: \(raiseResult.rawValue)")

                            // Also try to set as main window
                            let setMainResult = AXUIElementSetAttributeValue(appElement, kAXMainWindowAttribute as CFString, window)
                            NSLog("MacWindowSwitch: [Engine] AX setMainWindow result: \(setMainResult.rawValue)")
                            foundMatch = true
                            break
                        }
                    }
                }
                if !foundMatch {
                    NSLog("MacWindowSwitch: [Engine] ⚠️ No AX window matched windowID \(windowID)")
                    NSLog("MacWindowSwitch: [Engine] → Private APIs should have handled activation, skipping AX fallback")
                    // Don't raise arbitrary windows - the private APIs (_SLPSSetFrontProcessWithOptions
                    // and makeKeyWindow) should have already done their job correctly.
                    // Raising the "first" window would often raise the wrong one!
                }
            } else {
                NSLog("MacWindowSwitch: [Engine] ⚠️ Could not get AX windows, copyResult: \(copyResult.rawValue)")
                // Fallback: just raise the app
                let raiseResult = AXUIElementPerformAction(appElement, kAXRaiseAction as CFString)
                NSLog("MacWindowSwitch: [Engine] AX raise app result: \(raiseResult.rawValue)")
            }

            NSLog("MacWindowSwitch: [Engine] ✅ Activation COMPLETE")

            // Note: We don't wait for completion or handle the result
            // This matches alt-tab-macos fire-and-forget behavior
        }
    }

    /// Makes a window the key window within its application
    ///
    /// Ported from alt-tab-macos Window.makeKeyWindow() (lines 207-217)
    /// Original implementation from: https://github.com/Hammerspoon/hammerspoon/issues/370#issuecomment-545545468
    ///
    /// This sends a specially-formatted byte array to the Window Server to make
    /// the specified window "key" (frontmost) within its application.
    ///
    /// - Parameters:
    ///   - windowID: The CGWindowID to make key
    ///   - psn: Process Serial Number of the window's owner (passed as inout)
    ///
    /// **Format Details:**
    /// The byte array is a low-level protocol understood by the Window Server.
    /// The exact format was reverse-engineered by the Hammerspoon project.
    /// Two messages are sent (one with bytes[0x08] = 0x01, one with 0x02).
    ///
    /// **Warning:** This is highly dependent on Window Server internals and
    /// may break in future macOS versions.
    private static func makeKeyWindow(windowID: CGWindowID, psn: inout ProcessSerialNumber) {
        // Create byte buffer exactly as alt-tab-macos does
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x3a] = 0x10

        // CRITICAL: Use memcpy exactly as AltTab/Hammerspoon does for binary protocol
        // Use intermediate variable to ensure proper memory layout
        var windowId = windowID
        memcpy(&bytes[0x3c], &windowId, MemoryLayout<UInt32>.size)

        // Set magic bytes at offset 0x20
        memset(&bytes[0x20], 0xff, 0x10)

        // Send first message (0x01)
        bytes[0x08] = 0x01
        let result1 = SLPSPostEventRecordTo(&psn, &bytes)
        NSLog("MacWindowSwitch: [Engine] SLPSPostEventRecordTo (0x01) result: \(result1)")

        // Send second message (0x02)
        bytes[0x08] = 0x02
        let result2 = SLPSPostEventRecordTo(&psn, &bytes)
        NSLog("MacWindowSwitch: [Engine] SLPSPostEventRecordTo (0x02) result: \(result2)")
    }

    /// Focus a window using Accessibility API
    ///
    /// This is the public API fallback strategy. It uses AXUIElement to raise
    /// the window, which works but doesn't support cross-space switching.
    ///
    /// - Parameter axElement: The AXUIElement representing the application
    /// - Throws: AXError if the raise action fails
    private static func focusWindow(_ axElement: AXUIElement) throws {
        let error = AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
        guard error == .success else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(error.rawValue))
        }
    }
}
