import ApplicationServices

// Accessibility CFTypes are not annotated for Sendable in SDK headers.
// We treat AXUIElement as @unchecked Sendable to allow passing between tasks,
// and we confine all cache mutations to MainActor for safety.
extension AXUIElement: @unchecked Sendable {}

