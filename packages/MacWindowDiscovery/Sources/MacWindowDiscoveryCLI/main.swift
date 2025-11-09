import Foundation
import ArgumentParser
import MacWindowDiscovery

struct MacWindowDiscoveryCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mac-window-discovery",
        abstract: "A tool for discovering and monitoring windows on macOS",
        version: "0.4.0",
        subcommands: [
            ListCommand.self,
            WatchCommand.self,
            AppCommand.self,
            PermissionsCommand.self
        ],
        defaultSubcommand: ListCommand.self
    )
}

MacWindowDiscoveryCLI.main()
