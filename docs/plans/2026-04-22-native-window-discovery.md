# Plan: `NativeBackend` — retrieve spaces/windows/apps without Yabai

## Context

SpacesBar today needs an external window manager (Yabai) to know which apps live on which Space. `BackendSelector.selectStartupBackend()` in `SpacesBar/SpacesBar/Backend.swift:8-12` hardcodes `YabaiBackend()`. Users without Yabai see "yabai unavailable" in the menu bar.

This plan adds a third backend — `NativeBackend` — that uses only macOS APIs: public `CGWindowListCopyWindowInfo` + `NSRunningApplication` plus the private (but rock-stable since Yosemite) CoreGraphics "CGS" Space symbols. No external process, no TCC prompt, no Accessibility requirement. The spec in `CLAUDE.md` already allows private APIs (no App Store goal) and forbids window titles (so Screen Recording isn't needed either).

Full technical research with signatures, dict shapes, edge cases and sources lives at `/Users/albert/projects/alber70g/spacesbar/SpacesBar/research/native-macos-spaces-windows-apis.md` (copied there once plan mode lifts — currently at `/Users/albert/.claude/plans/research-and-make-a-distributed-wirth-agent-a09ffac8e03ce91b7.md`).

**Scope of this change:** add the backend and make it selectable. Wiring for event-driven refresh via `NSWorkspace.activeSpaceDidChangeNotification` is included; the existing 5s fallback timer still runs. We do **not** redesign the event-bridge architecture — we just introduce a thin `EventBridge` protocol so the native backend can plug in its own observers instead of the Yabai file watcher.

---

## Files to add / modify

Source layout is flat at `SpacesBar/SpacesBar/*.swift` (not nested under `App/Backends/…` as the early spec sketched).

### New files

1. `SpacesBar/SpacesBar/SpacesBar-Bridging-Header.h` — 5 C extern declarations for the private CGS symbols. Use the bridging-header pattern (WhichSpace-style) over `@_silgen_name` — safer across Swift versions and keeps the C types in one place.
2. `SpacesBar/SpacesBar/CGSPrivate.swift` — tiny Swift wrapper exposing `CGSSpaceType` enum + a helper `cgsAllSpacesMask: Int32 = 7`. Keeps magic numbers out of `NativeBackend`.
3. `SpacesBar/SpacesBar/NativeBackend.swift` — implements `Backend`. Target ≤150 lines.
4. `SpacesBar/SpacesBar/NativeEventBridge.swift` — wraps `NSWorkspace.shared.notificationCenter` observers (`activeSpaceDidChangeNotification`, `didLaunchApplicationNotification`, `didTerminateApplicationNotification`) and `NSApplication.didChangeScreenParametersNotification`. Target ≤80 lines.
5. `SpacesBar/SpacesBar/EventBridge.swift` — small protocol `{ start(onEvent:), stop() }` that both `YabaiEventBridge` and `NativeEventBridge` conform to.

### Modified files

6. `SpacesBar/SpacesBar/Backend.swift` — extend `BackendSelector` to pick between `yabai` and `native` based on config; expose matching `selectStartupEventBridge()` returning a `any EventBridge`.
7. `SpacesBar/SpacesBar/AppConfig.swift` — add `backend: BackendKind` field (`.yabai` | `.native`), default `.native` for new installs (it's the zero-config path). Preserve existing users who have a saved config without the field → decode to `.yabai` for backward compatibility. Include legacy-string tolerance à la `IconStyle.init(from:)`.
8. `SpacesBar/SpacesBar/AppController.swift` — replace the hardcoded `YabaiEventBridge()` at line 10 with `BackendSelector.selectStartupEventBridge(for: config.backend)`. Also make the failure message generic: `"\(backend.id) unavailable"` instead of hardcoded `"yabai unavailable"` at line 83.
9. `SpacesBar/SpacesBar/StatusBarController.swift` — add a "Backend" submenu mirroring the existing "Icon Style" pattern so users can switch without editing JSON. (Optional for MVP; include as Milestone B below.)
10. Xcode project (`SpacesBar.xcodeproj/project.pbxproj`) — set `SWIFT_OBJC_BRIDGING_HEADER = SpacesBar/SpacesBar-Bridging-Header.h` and add `-framework SkyLight` to `OTHER_LDFLAGS` for the `SpacesBar` target. Hardened runtime is already on; no entitlement changes.

---

## Milestone A — minimum viable native backend

Order matters: later steps depend on earlier ones compiling.

1. **Bridging header + pbxproj wiring.** Add `SpacesBar-Bridging-Header.h` with 5 externs (`CGSMainConnectionID`, `CGSGetActiveSpace`, `CGSCopyManagedDisplaySpaces`, `CGSCopySpacesForWindows`, `CGSSpaceGetType`). Set `SWIFT_OBJC_BRIDGING_HEADER` and add `-framework SkyLight` to `OTHER_LDFLAGS`. Verify with a stub `print(CGSMainConnectionID())` in a trivial target before touching anything else — this is the riskiest step.
2. **`EventBridge` protocol.** Extract the current `YabaiEventBridge.start(onEvent:) / stop()` shape into `protocol EventBridge: AnyObject`. Make `YabaiEventBridge` conform. No behavior change.
3. **`BackendKind` enum + `AppConfig.backend`.** Add `.yabai` / `.native` cases. Default-for-new-install = `.native`; if JSON decode finds no field, default to `.yabai` (preserve existing users). Mirror `IconStyle`'s legacy-string tolerance in `init(from:)`.
4. **`NativeBackend.swift`.** Implements `Backend` with `id = "native"`. Steps inside `fetchSnapshot()`:
   - `CGSMainConnectionID()` once.
   - `CGSCopyManagedDisplaySpaces(cid)` → iterate displays → parse `Spaces` + `Current Space` dicts. For each space capture `id64`, `ManagedSpaceID`, `type`, per-display-index.
   - `CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)`. Filter: `layer==0`, `alpha>0`, `storeType==1`, `pid != getpid()`, owner ∉ {`Window Server`,`Dock`}, bounds W/H ≥ 50.
   - Build PID → `NSRunningApplication` map from `NSWorkspace.shared.runningApplications` (reusing the pattern already in `YabaiBackend.reduceWindow` at `YabaiBackend.swift:62-83`).
   - For each window's wid: `CGSCopySpacesForWindows(cid, 7, [wid] as CFArray)` → set of `CGSSpaceID`. Accumulate `spaceID -> Set<pid_t>`.
   - For each space (in `CGSCopyManagedDisplaySpaces` order, flattened across displays — preserve display-group ordering, skip `type==4` fullscreen spaces from the app-listing for v1 or label them `F` per-app; pick the simpler "skip fullscreen" path for MVP to avoid label ambiguity), build `SpaceSnapshot` using the existing `AppSnapshot.deduplicationKey` helper from `SnapshotModels.swift:24-38`.
   - `displayLabel = String(ManagedSpaceID)` — matches how Spotlight/macOS labels "Desktop N". `focusedSpaceID = String(CGSGetActiveSpace(cid))`.
   - Reuse `AppSnapshot` alphabetical sort from `YabaiBackend.deduplicatedApps` at `YabaiBackend.swift:57-59`.
5. **`NativeEventBridge.swift`.** Observe on `NSWorkspace.shared.notificationCenter`: `activeSpaceDidChangeNotification`, `didLaunchApplicationNotification`, `didTerminateApplicationNotification`. Observe on `NotificationCenter.default`: `NSApplication.didChangeScreenParametersNotification`. Each posts `onEvent()` on main queue. `stop()` removes all observers.
6. **`BackendSelector` split.** Return `(any Backend, any EventBridge)` — or two separate factory functions keyed by `BackendKind`. Call sites in `AppController.init` at `AppController.swift:10-16`.
7. **Generic failure string.** Change `AppController.swift:83` from `"yabai unavailable"` to `"\(backend.id) unavailable"`.

### Reuse / do not duplicate

- `AppSnapshot` struct + `deduplicationKey` — unchanged (`SnapshotModels.swift:15-38`).
- `NSRunningApplication(processIdentifier:)` lookup pattern — copy shape from `YabaiBackend.swift:67`.
- Alphabetical app sort — copy from `YabaiBackend.swift:57-59`.
- `AppLogger.shared.log()` — use for the one-time "native backend up" log + any parse-fail debug lines.
- `IconCache` — no changes needed. `AppSnapshot`'s existing fields feed it the same way regardless of backend.

---

## Milestone B — UX polish (optional follow-up; not strictly required)

- Add a "Backend" submenu in `StatusBarController` matching the existing "Icon Style" pattern. Writes through `AppConfigStore.update { $0.backend = … }`, then triggers an `AppController` reset that tears down the current backend + event bridge and reconstructs from config. Cost: ~40 lines in `StatusBarController.swift` + ~20 in `AppController`.
- Document "disable Mission Control → Automatically rearrange Spaces based on most recent use" in a new `Docs/native-setup.md` — otherwise space labels can reshuffle across sessions.

---

## Known edge cases already factored in (see research file for full detail)

- Multi-display + "Displays have separate Spaces" ON: iterate all displays in the outer array; use each display's own `Current Space` for per-display focus if we want it, otherwise the global `CGSGetActiveSpace` is fine.
- Fullscreen spaces (`type==4`): skip for v1 (simpler labels). Revisit once users ask.
- Assign-to-all-spaces apps (Finder, 1Password floaters): `CGSCopySpacesForWindows` legitimately returns every space — they'll show up everywhere, which matches user expectation.
- Unmaterialized spaces: appear in the managed-display dict but no windows map to them → render empty (matches `hideEmptySpaces` toggle semantics).
- Sonoma/Sequoia/Tahoe: symbols confirmed stable in shipping 2025–2026 projects (WhichSpace 0.17.x, AltTab, Amethyst).

---

## Verification

1. **Compiles with bridging header.** After step 1: `xcodebuild -project SpacesBar.xcodeproj -target SpacesBar -configuration Debug build` succeeds. If the bridging-header setting is wrong you'll see "Use of unresolved identifier 'CGSMainConnectionID'".
2. **Native backend smoke test at runtime.** Launch app with `backend = "native"` in `~/Library/Application Support/SpacesBar/config.json`. Menu bar should show `1 [icons]  2 [icons] …` matching the current Spaces arrangement *without* Yabai running. Verify by running `pgrep yabai` — should be empty.
3. **Space-switch event latency.** Ctrl-→ to next Space. Menu bar should update within one animation frame (~250ms) — that's `activeSpaceDidChangeNotification` doing its job. If it takes 5s, the fallback timer is the one updating and the observer didn't wire.
4. **App launch/quit updates.** Open/quit a non-background app. Menu bar reflects within ~1s (workspace notification).
5. **Multi-display check (if available).** Plug in external monitor, enable "Displays have separate Spaces", verify both displays' spaces show up in order.
6. **Graceful degradation.** In config, set `backend = "yabai"` while Yabai is running → still works. Kill Yabai → `"yabai unavailable"` shows. Switch back to `"native"` → recovers without restart if using the Backend submenu; otherwise restart.
7. **CPU check.** `sample SpacesBar 5` while idle on a static Space. Should show near-zero non-timer activity — no runaway CGS polling.
8. **Reduction unit test.** Add one test fixture under `SpacesBar/Tests/` (directory doesn't exist yet — create it) parsing a pre-captured `CGSCopyManagedDisplaySpaces`-shaped `[[String:Any]]` dict (see `InstantSpaceSwitcher/Sources/ISS/ISS.c` for real shape) and asserting the reduction produces the expected `[SpaceSnapshot]`. Unit-level only; the CGS calls themselves don't need mocking.

---

## Risk register (short)

- **Private API drift on future macOS.** Wrap CGS calls with a lightweight availability check — if `CGSCopyManagedDisplaySpaces` returns `nil`/empty, `NativeBackend.fetchSnapshot()` throws, `AppController` surfaces "native unavailable", user falls back to Yabai.
- **Bridging-header setting not picked up by SwiftPM / SPM-only flows.** Project is Xcode-based (`SpacesBar.xcodeproj`), so `SWIFT_OBJC_BRIDGING_HEADER` is the right lever. If we ever migrate to SPM we'd need a `module.modulemap` — not a concern for this plan.
- **Notarization.** Already working for this app; CGS symbols don't trip notary checks (WhichSpace/Spaceman ship through Homebrew cask with identical symbol use).
