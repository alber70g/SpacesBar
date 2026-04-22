# SpacesBar Milestone 1 Design

Date: 2026-04-22
Status: Approved

## Scope

This document captures the approved design for the first implementation slice of SpacesBar.

Milestone 1 in this slice includes:

- Launch as a menu bar utility with no Dock icon
- Select one backend at startup through a backend abstraction
- Support Yabai only for now
- Fetch a snapshot once on launch and then every 5 seconds as a fallback
- Render spaces and apps as plain text in the menu bar
- Suppress rerenders when the reduced snapshot is unchanged
- Show `yabai unavailable` when the backend is unavailable or returns invalid data at launch

This slice intentionally does not include:

- AeroSpace support
- Icon rendering
- Icon caching
- Event bridge
- Config file parsing
- Focused-space emphasis
- Rich diagnostics

## Product Decision Notes

There is a temporary scope override relative to the broader repo spec:

- The long-term v1 acceptance criteria mention app icons
- The immediate implementation request narrows the first slice to text rendering such as `1 [Chrome] | 2 [Telegram]`

The design keeps the backend and snapshot model compatible with later icon support so that the next milestone can add icons without replacing the core architecture.

## Architecture

Milestone 1 uses a small native AppKit-based structure:

1. `SpacesBarApp`
   - Boots the application
   - Configures the app as a menu bar utility
   - Creates the top-level controller

2. `AppController`
   - Selects the backend at startup
   - Triggers the initial fetch
   - Starts the 5 second fallback refresh timer
   - Routes snapshots and failures to the status bar controller

3. `Backend`
   - Protocol for backend selection
   - Only `YabaiBackend` exists in this slice

4. `YabaiBackend`
   - Runs `yabai -m query --spaces`
   - Runs `yabai -m query --windows`
   - Decodes JSON in-process
   - Reduces raw backend data to an ordered snapshot

5. `SnapshotStore`
   - Holds the last reduced snapshot
   - Decides whether a new snapshot is meaningfully different
   - Prevents redundant status bar updates

6. `StatusBarController`
   - Owns `NSStatusItem`
   - Updates the displayed text only when needed
   - Shows backend failure text when no valid snapshot is available

7. `StatusBarRenderer`
   - Converts the reduced snapshot into a single compact string
   - Contains no backend logic

## Data Model

The reduced model is intentionally minimal and render-focused.

```swift
struct BackendSnapshot: Equatable {
    let focusedSpaceID: String?
    let spaces: [SpaceSnapshot]
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
}
```

This shape is sufficient for text rendering now and icon lookup later.

## Backend Contract

Backend selection is protocol-based from day one even though only Yabai is implemented.

```swift
protocol Backend {
    var id: String { get }
    func fetchSnapshot() async throws -> BackendSnapshot
}
```

Milestone 1 does not require a separate availability API. A failed fetch is enough to drive the `yabai unavailable` state.

## Yabai Reduction Rules

Input sources:

- `yabai -m query --spaces`
- `yabai -m query --windows`

Reduction rules:

- Sort spaces by Mission Control index ascending
- Include empty spaces
- Associate windows to spaces using Yabai space identifiers
- Deduplicate apps within a space
- Prefer stable app identity keys in this order:
  1. `bundleID`
  2. `bundlePath`
  3. `pid + displayName`
- Skip windows that cannot provide enough information to build an app snapshot

## Rendering Rules

The menu bar renders a single line of plain text.

Examples:

- `1 [Chrome] | 2 [Telegram]`
- `1 [Safari] [Mail] | 2 | 3 [iTerm2]`

Rules:

- Render spaces left to right in stable order
- Render the space label first
- Render each unique app name wrapped in brackets
- Separate spaces with ` | `
- Empty spaces render only their label

Focused-space styling is explicitly deferred to Milestone 2.

## Refresh Strategy

Milestone 1 uses manual refresh only:

- Fetch immediately on launch
- Fetch every 5 seconds using a low-frequency fallback timer

There is no event bridge yet. The timer is intentionally slow to keep idle CPU low.

## Error Handling

If the first fetch fails because Yabai is missing, not responding, or returns invalid JSON:

- The status item is still created
- Its title is set to exactly `yabai unavailable`

If a later fetch fails after a valid snapshot has already been rendered:

- Preserve the last good render
- Do not clear the menu bar title

This keeps the UI stable and avoids flicker.

## Verification Targets

Milestone 1 is complete when:

1. The app launches as a menu bar utility with no Dock icon
2. Backend selection happens through a startup abstraction
3. The Yabai backend fetches spaces and windows and reduces them correctly
4. The status item renders stable ordered plain text output
5. Empty spaces are shown
6. Identical snapshots do not trigger rerender
7. Launch failure renders `yabai unavailable`
