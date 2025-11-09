import Foundation
import ApplicationServices

struct AXRemoteTokenEnumerator {
    private let tokenSize = 20
    private let magic: Int32 = 0x636f636f // "coco"

    /// Enumerate AX window elements for a process by iterating AXUIElementIDs.
    /// Enumeration is time-bounded to avoid blocking the UI for long.
    func enumerateWindows(for pid: pid_t, maxElementID: Int = 1000, timeBudgetMs: Int = 100) -> [AXUIElement] {
        // Guard: respect accessibility permission
        if !AXIsProcessTrusted() { return [] }

        var token = Data(count: tokenSize)
        token.replaceSubrange(0..<4, with: withUnsafeBytes(of: pid) { Data($0) })
        token.replaceSubrange(4..<8, with: withUnsafeBytes(of: Int32(0)) { Data($0) })
        token.replaceSubrange(8..<12, with: withUnsafeBytes(of: magic) { Data($0) })

        var results: [AXUIElement] = []
        let start = DispatchTime.now().uptimeNanoseconds

        for id in 0..<maxElementID {
            token.replaceSubrange(12..<20, with: withUnsafeBytes(of: UInt64(id)) { Data($0) })
            if let element = _AXUIElementCreateWithRemoteToken(token as CFData)?.takeRetainedValue() {
                var subroleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef) == .success,
                   let subrole = subroleRef as? String,
                   subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole {
                    results.append(element)
                }
            }
            let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000.0
            if elapsedMs > Double(timeBudgetMs) { break }
        }
        return results
    }
}
