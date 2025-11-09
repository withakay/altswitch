# MacWindowDiscovery Technical Specification

Version: 0.1 (MVP)
Owner: AltSwitch Platform
Status: Draft (Implemented MVP APIs)

## 1. Purpose & Scope

MacWindowDiscovery provides a focused, reusable library for discovering macOS application windows, resolving window identity (CGWindowID → PID), and preparing Accessibility (AX) references for cross‑Space activation. It is designed to:

- Supply other packages (e.g., MacWindowSwitch, AltSwitch app) with fast, window‑centric identity and AX context.
- Keep the AltSwitch app thin by encapsulating low‑level discovery logic and AX interactions.
- Be event‑friendly and time‑bounded: quick warm‑up at startup, then rely on OS events and on‑demand targeted enumeration (no periodic heavy sweeps).

Out of scope:
- Window activation (handled by MacWindowSwitch)
- UI, preference, or persistence concerns

## 2. Design Principles

- Minimal public API surface; internal helpers handle private details.
- Time‑bounded operations for responsiveness (tight budgets; small concurrency).
- MainActor confinement for AX cache mutations; background threads for heavy AX work.
- Event‑driven freshness: prefer OS notifications to periodic global sweeps.
- No UI dependencies; composable in CLI or app contexts.

## 3. Dependencies & Permissions

- Requires Accessibility permission for AX enumeration (`AXIsProcessTrusted()`), otherwise functions return early with safe defaults.
- Uses CoreGraphics public APIs and private AX entry points (bridged via `_silgen_name`).
- No sandbox support (uses private APIs and system‑wide enumeration).

## 4. Public API Surface

### 4.1 Window Identity

- File: `packages/MacWindowDiscovery/Sources/MacWindowDiscovery/Identity/WindowIdentityResolver.swift:1`

```
public struct WindowIdentityResolver {
  public init() {}
  nonisolated public func resolveProcessID(for windowID: CGWindowID) -> pid_t?
}
```

Behavior:
- Scans `CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID)` to map a `CGWindowID` to its owning PID.
- Returns `nil` when the window is not present.

### 4.2 AX Cache (MainActor)

- File: `packages/MacWindowDiscovery/Sources/MacWindowDiscovery/AX/AXElementStore.swift:1`

```
@MainActor
public final class AXElementStore {
  public static let shared: AXElementStore
  public func set(_ element: AXUIElement, for windowID: CGWindowID)
  public func get(for windowID: CGWindowID) -> AXUIElement?
  public func remove(for windowID: CGWindowID)
  public func clear()
  public var count: Int { get }
}
```

Behavior:
- Stores AXUIElement handles by CGWindowID.
- Thread‑safety via MainActor confinement.

### 4.3 AX Warm‑up & On‑Demand Ensure

- File: `packages/MacWindowDiscovery/Sources/MacWindowDiscovery/AX/AXWarmup.swift:1`

```
public enum AXWarmup {
  public static func warmUpAXCacheForAllRunningApps(
    timeoutPerAppMs: Int = 50,
    maxConcurrent: Int = 4
  ) async

  public static func axElement(
    for windowID: CGWindowID,
    ensurePopulated: Bool = true
  ) async -> AXUIElement?
}
```

Behavior:
- Warm‑up: background, non‑blocking, time‑bounded per app, limited concurrency; batches cache writes on MainActor.
- On‑demand ensure: if cache miss, resolves PID and runs a small per‑PID brute‑force AX enumeration before returning.

## 5. Internal Components (Not Public API)

### 5.1 Private AX Bridges

- File: `packages/MacWindowDiscovery/Sources/MacWindowDiscovery/AX/PrivateAX.swift:1`

```
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ wid: UnsafeMutablePointer<CGWindowID>) -> AXError

@_silgen_name("_AXUIElementCreateWithRemoteToken")
func _AXUIElementCreateWithRemoteToken(_ data: CFData) -> Unmanaged<AXUIElement>?
```

Notes:
- Private APIs; subject to change across macOS versions.

### 5.2 AX Remote Token Enumerator

- File: `packages/MacWindowDiscovery/Sources/MacWindowDiscovery/AX/AXRemoteTokenEnumerator.swift:1`

```
struct AXRemoteTokenEnumerator {
  func enumerateWindows(
    for pid: pid_t,
    maxElementID: Int = 1000,
    timeBudgetMs: Int = 100
  ) -> [AXUIElement]
}
```

Behavior:
- Builds 20‑byte remote tokens (4 bytes pid, 4 zero, 4 magic 0x636f636f, 8 AXUIElementID).
- Iterates AXUIElementID 0..maxElementID with a strict time budget; filters elements by subrole (AXStandardWindow, AXDialog).
- Returns AXUIElements to be mapped to `CGWindowID` via `_AXUIElementGetWindow`.

### 5.3 Concurrency Shims

- File: `packages/MacWindowDiscovery/Sources/MacWindowDiscovery/AX/ConcurrencyShims.swift:1`

```
extension AXUIElement: @unchecked Sendable {}
```

Rationale:
- AXUIElement is a CFType lacking Sendable conformance; we constrain cache writes to MainActor and treat handles as opaque tokens across tasks.

## 6. Data Model

- Cache key: `CGWindowID`
- Value: `AXUIElement`
- Future metadata (optional): `pid`, `lastSeen`, `flags`

## 7. Concurrency Model

- AX enumeration: background tasks (non‑MainActor), small per‑app/ per‑PID time budgets.
- Cache mutations: always MainActor.
- Warm‑up concurrency: controlled via an async gate to limit parallel work.

## 8. Event‑Driven Integration

MacWindowDiscovery remains agnostic of OS event wiring. Consumers (AltSwitch app) should:
- Subscribe to AX events (window created/destroyed, title/geometry changes) and NSWorkspace events (running apps change).
- Invalidate cache entries on AX destroyed / app terminated.
- Optionally call `AXWarmup.axElement(for:ensurePopulated:)` when focusing a specific window if cache miss.

This mirrors AltTab’s approach: background warm‑up + event updates + targeted re‑discovery when needed.

## 9. Performance & Time Budgets

- Default warm‑up per app: 50 ms (tunable)
- Default max concurrent apps: 3–4 (tunable)
- On‑demand ensure per PID: ~60 ms budget (tunable)
- All numbers are heuristics; adjust empirically based on hardware and app counts.

## 10. Error Handling & Edge Cases

- Missing permissions: return early, do nothing.
- No crashes on private API failures; simply skip entries.
- AX enumeration can miss long‑lived apps where AXUIElementID exceeds the probed range (rare in practice); on‑demand ensure can be re‑invoked.

## 11. Security & Privacy

- Reads local window metadata and AX handles; no network IO.
- Requires Accessibility permission; no data exfiltration.
- Uses private AX APIs; not App Store‑friendly.

## 12. Limitations

- Reliance on private APIs (`_AXUIElementCreateWithRemoteToken`, `_AXUIElementGetWindow`).
- AX enumeration is best‑effort; may miss rare cases under tight budgets.
- No built‑in Spaces metadata; consumers can enrich via SkyLight/CGS APIs if needed.

## 13. Usage Examples

### 13.1 Startup Warm‑up (AltSwitch)

File: `AltSwitch/AltSwitch/Services/AppManagement/AppSwitcher.swift:1`

```swift
init() {
  Task.detached {
    await AXWarmup.warmUpAXCacheForAllRunningApps(timeoutPerAppMs: 50, maxConcurrent: 3)
  }
}
```

### 13.2 Activation Dependencies (AltSwitch → MacWindowSwitch)

```swift
let deps = ActivationDependencies(
  pidResolver: { id in WindowIdentityResolver().resolveProcessID(for: id) },
  axResolver: { id in await AXWarmup.axElement(for: id, ensurePopulated: false) }
)

try WindowActivator.activate(windowID: cgWindowId, dependencies: deps)
```

## 14. Testing Strategy

- Unit tests for identity resolver: mock CGWindowList.
- AX cache tests: MainActor CRUD; ensure no crashes when adding/removing.
- Enumerator tests: verify time budget enforcement with synthetic timers.
- Integration: simulate cache miss → on‑demand ensure populates → activation finalize succeeds.

## 15. Future Enhancements

- Event‑driven invalidation helpers:
  - remove(forPID:), markSeen(windowID:)
- Spaces metadata enrichment APIs (via SkyLight): window → space IDs
- Structured logging/metrics (warm‑up durations, cache hits/misses)
- Configurable budgets from consumer app
- Optional capacity/TTL safeguards (only if memory pressure observed)

---

References:
- AltTab audit: `docs/alttab-window-activation-audit.md`
- Integration plan: `docs/alt-switch-window-activation-integration-plan.md`
