//
//  main.swift
//  MacWindowSwitchCLI
//
//  CLI tool for MacWindowSwitch - Minimal implementation for Phase 0
//

@preconcurrency import ArgumentParser
@preconcurrency import ApplicationServices
import Foundation
import MacWindowSwitch

@main
struct MacWindowSwitchCLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "mac-window-switch",
        abstract: "Activate macOS windows across spaces and displays",
        version: "0.1.0-alpha",
        subcommands: [
            Activate.self,
            Permissions.self
        ]
    )
}

// MARK: - Activate Command

struct Activate: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Activate a window by its ID and process ID"
    )

    @Option(name: .shortAndLong, help: "Window ID (CGWindowID)")
    var windowId: UInt32

    @Option(name: .shortAndLong, help: "Process ID of window owner")
    var pid: Int32

    mutating func run() throws {
        print("MacWindowSwitch CLI - Activating window \(windowId) for process \(pid)")

        do {
            try WindowActivator.activate(windowID: CGWindowID(windowId), processID: pid_t(pid))
            print("✅ Activation request sent successfully")
            print("   (Window activation happens asynchronously in background)")

            // Sleep briefly to allow activation to complete before exiting
            Thread.sleep(forTimeInterval: 0.5)
        } catch {
            print("❌ Activation failed: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

// MARK: - Permissions Command

struct Permissions: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Check and request Accessibility permissions"
    )

    @Flag(name: .shortAndLong, help: "Request permission (opens System Settings)")
    var request: Bool = false

    mutating func run() {
        print("MacWindowSwitch CLI - Permissions Check")
        print("")

        // Check if accessibility is trusted
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            print("✅ Accessibility permission: GRANTED")
            print("   MacWindowSwitch has the required permissions")
        } else {
            print("❌ Accessibility permission: DENIED")
            print("   MacWindowSwitch requires Accessibility permission to activate windows")
            print("")
            print("   To grant permission:")
            print("   1. Open System Settings")
            print("   2. Go to Privacy & Security > Accessibility")
            print("   3. Enable access for mac-window-switch")

            if request {
                print("")
                print("   Opening System Settings now...")
                WindowActivator.requestAccessibilityPermission()
            } else {
                print("")
                print("   Run with --request to open System Settings automatically")
            }
        }
    }
}

