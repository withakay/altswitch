import Foundation
import ArgumentParser
import MacWindowDiscovery

struct PermissionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "permissions",
        abstract: "Check and request required permissions"
    )

    @Flag(name: .long, help: "Request permissions if not granted")
    var request = false

    func run() throws {
        print("MacWindowDiscovery Permission Status\n")

        // Check Accessibility permission
        let hasAX = WindowDiscoveryEngine.hasAccessibilityPermission()
        print("Accessibility API: \(hasAX ? "✓ Granted" : "✗ Not granted")")
        if !hasAX {
            print("  Required for: Window state (minimized, hidden, focused)")
            print("  Required for: Accurate window titles")
        }

        // Check Screen Recording permission
        let hasSR = WindowDiscoveryEngine.hasScreenRecordingPermission()
        print("Screen Recording: \(hasSR ? "✓ Granted" : "✗ Not granted")")
        if !hasSR {
            print("  Optional: May be required for some window metadata")
        }

        print()

        if !hasAX && request {
            print("Requesting Accessibility permission...")
            let granted = try runAsync {
                await WindowDiscoveryEngine.requestAccessibilityPermission()
            }
            if granted {
                print("✓ Permission granted!")
            } else {
                print("✗ Permission denied or dialog shown")
                print("\nPlease:")
                print("1. Open System Settings")
                print("2. Go to Privacy & Security → Accessibility")
                print("3. Enable access for Terminal (or your app)")
            }
        } else if !hasAX {
            print("Run with --request to request permissions")
            print("Or manually enable in: System Settings → Privacy & Security → Accessibility")
        }

        if !hasAX || !hasSR {
            print("\nNote: The tool will work with reduced functionality without these permissions.")
            print("Use --fast mode to skip Accessibility API entirely for better performance.")
        }
    }
}
