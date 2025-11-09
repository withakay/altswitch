import Foundation

/// Helper to run async code synchronously
/// This uses a nested RunLoop to avoid blocking the main thread
@available(macOS 10.15, *)
func runAsync<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) throws -> T {
    var result: Result<T, Error>?

    Task {
        do {
            let value = try await operation()
            result = .success(value)
        } catch {
            result = .failure(error)
        }
    }

    // Run the run loop until we have a result
    // This allows MainActor tasks to execute while we wait
    while result == nil {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
    }

    return try result!.get()
}
