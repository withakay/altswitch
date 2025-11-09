import Foundation
import AppKit
import ApplicationServices

public enum AXWarmup {
    /// Populate the AX element cache for all running apps on background tasks.
    /// Uses a small per-app time budget and limits concurrency to keep UI responsive.
    public static func warmUpAXCacheForAllRunningApps(timeoutPerAppMs: Int = 50, maxConcurrent: Int = 4) async {
        guard AXIsProcessTrusted() else { return }
        let apps = NSWorkspace.shared.runningApplications.filter { $0.processIdentifier > 0 }
        let gate = ConcurrencyGate(maxConcurrent)
        await withTaskGroup(of: Void.self) { group in
            for app in apps {
                group.addTask {
                    await gate.acquire()
                    let enumerator = AXRemoteTokenEnumerator()
                    let elements = enumerator.enumerateWindows(for: app.processIdentifier, timeBudgetMs: timeoutPerAppMs)
                    if !elements.isEmpty {
                        await MainActor.run {
                            for element in elements {
                                var wid: CGWindowID = 0
                                if _AXUIElementGetWindow(element, &wid) == .success,
                                   wid != 0, wid != CGWindowID(bitPattern: -1) {
                                    AXElementStore.shared.set(element, for: wid)
                                }
                            }
                        }
                    }
                    await gate.release()
                }
            }
        }
    }

    /// Return a cached AX element for a window; optionally attempt a quick populate for its PID without blocking UI.
    public static func axElement(for windowID: CGWindowID, ensurePopulated: Bool = true) async -> AXUIElement? {
        if let cached = await MainActor.run(body: { AXElementStore.shared.get(for: windowID) }) { return cached }
        guard ensurePopulated, AXIsProcessTrusted() else { return nil }
        let resolver = WindowIdentityResolver()
        guard let pid = resolver.resolveProcessID(for: windowID) else { return nil }
        let elements = AXRemoteTokenEnumerator().enumerateWindows(for: pid, timeBudgetMs: 60)
        if elements.isEmpty { return await MainActor.run { AXElementStore.shared.get(for: windowID) } }
        await MainActor.run {
            for element in elements {
                var wid: CGWindowID = 0
                if _AXUIElementGetWindow(element, &wid) == .success,
                   wid != 0, wid != CGWindowID(bitPattern: -1) {
                    AXElementStore.shared.set(element, for: wid)
                }
            }
        }
        return await MainActor.run { AXElementStore.shared.get(for: windowID) }
    }
}

// Simple async concurrency gate to limit concurrent warm-up tasks.
actor ConcurrencyGate {
    private var permits: Int
    init(_ permits: Int) { self.permits = max(1, permits) }
    func acquire() async {
        while permits == 0 { await Task.yield() }
        permits -= 1
    }
    func release() { permits += 1 }
}
