
# Spacesbar v1 Spec

## Summary

Spacesbar is a lightweight macOS menu bar application that shows which apps are active on which spaces or workspaces.

Example output:

`1 [Chrome] [WhatsApp]  2 [VS Code] [iTerm2]  5 [LM Studio]`

The project is open source and optimized for low CPU and memory usage. It is not intended for the Mac App Store. It relies on external window manager backends to provide space/workspace membership information.

## Primary Goal

Build a tiny native macOS status bar app that renders:

* a stable ordered list of spaces/workspaces
* each space/workspace number or label
* zero or more app icons for apps present on that space/workspace
* compact spacing between spaces/workspaces

## Non-Goals for v1

* No per-window titles
* No per-window counts in the UI
* No drag-and-drop interaction
* No popover or configuration window required for v1
* No Accessibility API dependency for core functionality
* No support for discovering app-to-space membership without an external backend
* No App Store support

## Supported Backends

### Backend 1: Yabai

Use Yabai for native macOS Spaces.

Semantics:

* Space identifiers are Mission Control indices
* The app should present them as numeric spaces: `1`, `2`, `3`, etc.
* Data source is `yabai -m query --spaces` and `yabai -m query --windows`

### Backend 2: AeroSpace

Use AeroSpace for AeroSpace workspaces.

Semantics:

* Identifiers are AeroSpace workspaces, not native macOS Spaces
* The app should present them using the workspace identifiers returned by AeroSpace
* Data source is `aerospace list-workspaces --all --json` and `aerospace list-windows --all --json`

## Product Requirements

### UI Requirements

The status item must render a single compact horizontal line.

Rules:

* Render spaces/workspaces left to right in stable sorted order
* For each space/workspace, render the identifier followed by app icons for unique apps on that space/workspace
* Empty spaces/workspaces render only the identifier
* Separate spaces/workspaces visually with spacing; a literal separator is optional
* Do not show duplicate app icons within the same space/workspace
* Prefer app icons from the actual application bundle
* Support icon rendering styles:

  * `native`
  * `template`
  * `softMono`
* The focused space/workspace may optionally use stronger text/icon opacity, but this must be subtle

### Performance Requirements

* Idle CPU usage should be near zero
* Updates should be event-driven when possible
* A slow fallback reconciliation timer is allowed
* No busy polling
* JSON output from backend commands must be parsed in-process; do not shell out to `jq`
* Keep in-memory model minimal: only retain current reduced snapshots needed for rendering and diffing
* Avoid recomputing icons unless the app identity, icon style, size, or appearance changed

### Compatibility Requirements

* macOS only
* Swift + AppKit
* Status bar item must work without showing a Dock icon
* The app should degrade gracefully if backend is unavailable or misconfigured

## Architecture

### High-Level Components

1. `App`

   * App lifecycle
   * menu bar setup
   * backend selection

2. `StatusBarController`

   * owns `NSStatusItem`
   * updates rendered content when snapshot changes

3. `Renderer`

   * converts a reduced snapshot into an attributed string or compact custom view model
   * no backend logic

4. `SnapshotStore`

   * holds last rendered snapshot
   * computes diffs
   * suppresses redundant renders

5. `IconPipeline`

   * resolves icons from running apps or bundle paths
   * rasterizes and post-processes icons
   * caches results

6. `Backend` protocol

   * shared interface for Yabai and AeroSpace adapters

7. `YabaiBackend`

   * fetches spaces and windows from Yabai
   * reduces them to app-per-space data

8. `AeroSpaceBackend`

   * fetches workspaces and windows from AeroSpace
   * reduces them to app-per-workspace data

9. `EventBridge`

   * receives external refresh signals when configured
   * triggers backend refreshes

10. `Config`

* reads user preferences and backend selection

## Backend Contract

Define a protocol like:

```swift
protocol Backend {
    var id: String { get }
    func checkAvailability() async -> BackendAvailability
    func fetchSnapshot() async throws -> BackendSnapshot
}
```

Suggested supporting types:

```swift
struct BackendAvailability {
    let isAvailable: Bool
    let reason: String?
}

struct BackendSnapshot: Equatable {
    let backendKind: BackendKind
    let focusedSpaceID: String?
    let spaces: [SpaceSnapshot]
    let generatedAt: Date
}

struct SpaceSnapshot: Equatable {
    let id: String
    let displayLabel: String
    let isFocused: Bool
    let apps: [AppSnapshot]
}

struct AppSnapshot: Equatable, Hashable {
    let bundleID: String?
    let pid: Int?
    let displayName: String
    let bundlePath: String?
    let iconKey: String
}
```

## Data Reduction Rules

### Yabai Reduction

Input:

* all spaces
* all windows

Output:

* one `SpaceSnapshot` per Yabai space
* each space contains unique apps derived from windows belonging to that space

Rules:

* sort spaces by Mission Control index ascending
* app uniqueness key preference:

  1. bundle ID
  2. bundle path
  3. pid + display name
* windows without enough information to identify an app may be skipped with debug logging
* include empty spaces

### AeroSpace Reduction

Input:

* all workspaces
* all windows

Output:

* one `SpaceSnapshot` per AeroSpace workspace
* each workspace contains unique apps derived from windows belonging to that workspace

Rules:

* sort workspaces in the order returned by explicit workspace list, unless a later config option overrides it
* app uniqueness key preference:

  1. bundle ID
  2. bundle path
  3. pid + display name
* include empty workspaces

## Refresh Strategy

### Primary Strategy

Refresh on explicit events.

Sources:

* app launch
* backend change
* external event bridge notifications
* optional local timer fallback

### Event Sources

#### Yabai

Allow users to configure Yabai signals externally to notify Spacesbar.

Examples of relevant events:

* space changed
* window created
* window destroyed
* window moved
* application visible state changed

Spacesbar should not own Yabai configuration in v1, but should document example user setup.

#### AeroSpace

Allow users to configure AeroSpace callbacks externally to notify Spacesbar.

Relevant events:

* workspace changed
* focus changed

Spacesbar should document example AeroSpace callback setup.

### Fallback Reconciliation

Use a low-frequency timer as a safety net.

Initial default:

* every 5 seconds while app is running

Rules:

* if newly fetched snapshot is equal to previous snapshot, do not rerender
* if backend is unavailable, back off and retry less frequently

## Rendering Strategy

### v1 Default

Use `NSStatusItem` with a custom attributed title or compact custom button view.

Preferred initial implementation:

* attributed string with text attachments for icons

Rendering rules:

* each space/workspace segment begins with the label
* icons follow with tight spacing
* icons should be visually aligned to text baseline
* separator between segments may be omitted if spacing keeps segments readable
* no truncation logic needed for first milestone if output fits typical menu bar width
* implement later overflow strategy if needed

### Optional Overflow Strategy

If total rendered width exceeds a threshold:

* render spaces/workspaces until limit reached
* show trailing `…`
* do not attempt horizontal scrolling

## Icon Pipeline

### Sources

Preferred icon resolution order:

1. `NSRunningApplication(processIdentifier:)?.icon`
2. `NSWorkspace.shared.icon(forFile: bundlePath)`
3. generic fallback icon

### Cache Key

Cache processed icons by:

* icon key
* size
* style
* appearance

### v1 Styles

#### native

* original app icon

#### template

* convert to monochrome/template-like rendering

#### softMono

* desaturate and normalize alpha/contrast for better consistency

### Constraints

* all icon processing must happen off the main thread when possible
* final UI application must happen on the main thread
* processed icons should be rasterized to the exact target display size and cached

## Configuration

Initial configuration can be file-based.

Current shipped menu options:

* Copy Current Output
* Hide Empty Spaces toggle, unchecked by default
* Quit SpacesBar

Suggested config fields:

```toml
backend = "yabai" # or "aerospace"
icon_style = "template" # native | template | softMono
icon_size = 13
refresh_fallback_seconds = 5
show_empty_spaces = true
log_level = "info"
```

Future config fields:

* max_icons_per_space
* focused_space_emphasis
* custom space ordering
* custom labels
* hidden apps

## Error Handling

### Backend Unavailable

If the selected backend cannot be found or queried:

* render a compact error state, e.g. `Spacesbar: backend unavailable`
* log a human-readable reason
* retry using backoff

### Partial Parse Failure

If part of a backend payload cannot be parsed:

* skip invalid entries
* preserve valid entries
* emit debug logs

## Logging

Use structured logging.

Levels:

* error
* info
* debug

Do not log on every successful refresh unless debug logging is enabled.

## Suggested Repo Layout

```text
spacesbar/
  App/
    SpacesbarApp.swift
    StatusBarController.swift
    Renderer.swift
    SnapshotStore.swift
    EventBridge.swift
  Backends/
    Backend.swift
    YabaiBackend.swift
    AeroSpaceBackend.swift
    DTOs/
  Icons/
    IconPipeline.swift
    IconCache.swift
    IconStyle.swift
  Models/
    Snapshot.swift
  Config/
    Config.swift
  Support/
    Shell.swift
    Logging.swift
  Docs/
    spec.md
    yabai-setup.md
    aerospace-setup.md
  Tests/
    SnapshotReductionTests.swift
    RendererTests.swift
    IconPipelineTests.swift
```

## Milestones

### Milestone 1

* Launch as menu bar app
* Select one backend at startup
* Fetch snapshot manually on launch and every fallback interval
* Render Yabai spaces and app icons in menu bar
* Cache icons

### Milestone 2

* Add event bridge
* Add backend availability checks and better error states
* Add focused-space emphasis
* Add config file parsing

### Milestone 3

* Add AeroSpace support if Yabai shipped first
* Add overflow handling
* Add richer diagnostics and example user integrations

## Acceptance Criteria for v1

* With Yabai configured, the app renders all current native spaces by numeric index and deduplicated app icons per space
* AeroSpace support may land after the initial Yabai-first v1 slice
* Idle CPU stays low and no high-frequency polling is used
* Repeated identical snapshots do not trigger rerender
* App icons are loaded from real application metadata whenever possible
* The app runs as a menu bar utility without a Dock icon

## Open Questions

1. Yabai-first is the current v1 direction; AeroSpace follows later.
2. Should workspace labels in AeroSpace mode be rendered raw or normalized?
3. Should focused app appear first within a space/workspace if known?
4. A tiny dropdown menu is already in use for copy, hide-empty-spaces, and quit.
5. Is attributed-string rendering sufficient, or should we start with a custom status item view?

## Codex Tasking Notes

When implementing this spec:

* prefer simple, explicit types over abstraction-heavy designs
* keep shell execution isolated in one small utility
* parse backend JSON into DTOs, then reduce into internal models
* write tests for reduction logic before polishing UI
* optimize for low render churn and icon cache reuse
* keep backend-specific semantics out of the renderer
