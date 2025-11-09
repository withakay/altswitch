# MacWindowSwitch Technical Specification

Version: 0.1 (MVP)
Owner: AltSwitch Platform
Status: Draft (Implemented MVP APIs)

## 1. Purpose & Scope

MacWindowSwitch provides reliable, cross‑Space window activation for macOS, targeting a specific `CGWindowID`. It encapsulates the activation strategies proven by AltTab:

- SkyLight per‑window activation that switches Spaces when needed.
- Window‑server event injection to make the exact window key.
- Optional Accessibility (AX) raise as a final nudge when an AX element is available.

Out of scope:
- Discovering windows or building AX caches (MacWindowDiscovery handles that).
- UI, configuration, or policy decisions.

## 2. Design Principles

- Window‑ID first: activation by `CGWindowID` is the primary API.
- Precise targeting: do not “raise the first AX window” on cache miss.
- Non‑blocking: all activation work executes off the main thread.
- Decoupled: process/AX resolution is injected (DI), keeping package reusable.

## 3. Dependencies & Permissions

- Requires Accessibility permission for AX raise fallback and permission checks.
- Uses private APIs from SkyLight and (deprecated) HIServices to perform cross‑Space activation.
- Not App Store compatible due to private API use.

## 4. Public API Surface

### 4.1 Activation (Synchronous Fire‑and‑Forget)

File: `packages/MacWindowSwitch/Sources/MacWindowSwitch/Core/WindowActivator.swift:1`

```
public struct WindowActivator {
  public static func activate(windowID: CGWindowID, processID: pid_t) throws
  public static func activate(windowID: CGWindowID, dependencies: ActivationDependencies? = nil) throws
  public static func requestAccessibilityPermission()
}
```

Behavior:
- `activate(windowID:processID:)` — direct path if caller already knows PID.
- `activate(windowID:dependencies:)` — window‑ID‑only path; uses injected resolvers for PID and AX element.
- Both methods return immediately; activation runs on a high‑priority background queue.

### 4.2 Dependency Injection for Resolution

File: `packages/MacWindowSwitch/Sources/MacWindowSwitch/Core/ActivationDependencies.swift:1`

```
public struct ActivationDependencies {
  public var pidResolver: (CGWindowID) -> pid_t?
  public var axResolver: @MainActor (CGWindowID) -> AXUIElement?
  public init(pidResolver: @escaping (CGWindowID) -> pid_t?,
              axResolver: @escaping @MainActor (CGWindowID) -> AXUIElement?)
}
```

Behavior:
- `pidResolver` — maps `CGWindowID` to PID (e.g., via `CGWindowListCopyWindowInfo`).
- `axResolver` — returns AXUIElement for a given `CGWindowID` if available (e.g., from a cache); if nil, AX finalize is skipped.

## 5. Activation Strategies (Engine)

File: `packages/MacWindowSwitch/Sources/MacWindowSwitch/Strategies/WindowActivationEngine.swift:1`

Order of operations:
1) Resolve PID (DI or fallback to CGWindowList).
2) Build `ProcessSerialNumber` using `GetProcessForPID` (HIServices).
3) SkyLight per‑window activation:
   - `_SLPSSetFrontProcessWithOptions(&psn, windowID, .userGenerated)` — switches Spaces and brings app to front.
4) Make exact window key via window‑server event:
   - `SLPSPostEventRecordTo(&psn, &bytes)` twice (0x01 / 0x02) with `wid` embedded at offset `0x3c`.
5) Optional AX finalize (only if `axResolver` returns an element):
   - `AXUIElementPerformAction(kAXRaiseAction)` — nudge the exact window to the front.

Important safeguards:
- Never “raise the first AX window” on cache miss; rely on SkyLight to target the intended window.
- All heavy work off main thread; only AX raise runs on MainActor if present.

## 6. Private API Surface

File: `packages/MacWindowSwitch/Sources/MacWindowSwitch/PrivateAPIs/SkyLight.swift:1`

```
@_silgen_name("_SLPSSetFrontProcessWithOptions")
func _SLPSSetFrontProcessWithOptions(_ psn: UnsafeMutablePointer<ProcessSerialNumber>,
                                     _ wid: CGWindowID,
                                     _ mode: SLPSMode.RawValue) -> CGError

@_silgen_name("SLPSPostEventRecordTo")
func SLPSPostEventRecordTo(_ psn: UnsafeMutablePointer<ProcessSerialNumber>,
                           _ bytes: UnsafeMutablePointer<UInt8>) -> CGError
```

File: `packages/MacWindowSwitch/Sources/MacWindowSwitch/PrivateAPIs/HIServices.swift:1`

```
@_silgen_name("GetProcessForPID")
func GetProcessForPID(_ pid: pid_t, _ psn: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
```

Notes:
- All three are private/legacy; they’re stable in practice but may change in future macOS releases.

## 7. Concurrency Model

- Background queue for activation: `ActivationQueue` (userInteractive QoS, max 4 concurrent ops).
  - File: `packages/MacWindowSwitch/Sources/MacWindowSwitch/Core/ActivationQueue.swift:1`
- Public APIs return immediately; activation continues in background.
- AX raise executes on MainActor if an AX element is provided by DI.

## 8. Error Handling & Fallbacks

- If PID cannot be resolved: log and skip activation.
- If SkyLight calls fail: no crash; operation completes with best effort.
- If AX element is missing: skip AX finalize; do not attempt a generic raise.
- Permission errors bubble as `accessibilityPermissionDenied` from `WindowActivator`.

## 9. CLI (Optional)

File: `packages/MacWindowSwitch/Sources/MacWindowSwitchCLI/main.swift:1`

Commands:
- `mac-window-switch activate --window-id <UInt32> --pid <Int32>`
- `mac-window-switch permissions --request` (optional prompt)

Notes:
- CLI expects both window ID and PID today; in app contexts, prefer the DI API to resolve PID.

## 10. Performance & Timing

- Designed for fast reaction under user interaction: high QoS operations; minimal main thread work.
- SkyLight API calls are typically low‑latency; AX raise is optional and quick.
- No polling or periodic scans.

## 11. Security & Privacy

- Uses Accessibility and private SkyLight/HIServices APIs; not App Store compatible.
- No network IO; operates on local window server state.

## 12. Integration Pattern (with MacWindowDiscovery)

Example (app layer):

```swift
let deps = ActivationDependencies(
  pidResolver: { id in WindowIdentityResolver().resolveProcessID(for: id) },
  axResolver: { id in await AXWarmup.axElement(for: id, ensurePopulated: false) }
)
try WindowActivator.activate(windowID: targetWindowId, dependencies: deps)
```

Notes:
- Warm‑up can run at startup (non‑blocking) to populate initial AX elements.
- Ongoing freshness comes from OS events; no periodic heavy sweeps needed.

## 13. Testing Strategy

- Unit tests:
  - Verify `ActivationQueue` limits concurrency.
  - DI: inject fake resolvers to test happy/error paths (PID found/missing; AX present/missing).
- Integration tests:
  - Ensure `_SLPSSetFrontProcessWithOptions` path is called and window becomes key.
  - Confirm no “first window” AX raise occurs on cache miss.

## 14. Future Enhancements

- Optional metrics hooks (activation duration, SkyLight result codes).
- Graceful macOS version feature flags if private APIs regress.
- Extended CLI that accepts window‑ID only and resolves PID within the server process.

---

References:
- Activation engine: `packages/MacWindowSwitch/Sources/MacWindowSwitch/Strategies/WindowActivationEngine.swift:1`
- Private APIs: `packages/MacWindowSwitch/Sources/MacWindowSwitch/PrivateAPIs/`
- Queue: `packages/MacWindowSwitch/Sources/MacWindowSwitch/Core/ActivationQueue.swift:1`
