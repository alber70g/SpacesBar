# SpacesBar Milestone 1 Implementation Plan

Date: 2026-04-22
Depends on: `2026-04-22-spacesbar-milestone-1-design.md`

## Goal

Implement the first working menu bar version of SpacesBar with Yabai support and plain text rendering.

## Success Criteria

1. Launches as a menu bar app without a Dock icon
2. Selects a backend through a protocol-based startup path
3. Fetches a snapshot on launch and every 5 seconds
4. Renders ordered plain text like `1 [Chrome] | 2 [Telegram]`
5. Includes empty spaces
6. Does not rerender when snapshots are identical
7. Shows `yabai unavailable` on startup failure

## Work Breakdown

### 1. Convert app shell to a status bar utility

Changes:

- Replace the default window-based `App` setup
- Add an app delegate or equivalent lifecycle bridge for AppKit setup
- Configure the generated Info.plist values so the app runs without a Dock icon

Verify:

- Build succeeds
- Launch produces a menu bar item
- No Dock icon appears

### 2. Add core snapshot and backend models

Changes:

- Introduce `Backend`, `BackendSnapshot`, `SpaceSnapshot`, and `AppSnapshot`
- Keep model types minimal and `Equatable`

Verify:

- Types compile cleanly
- Snapshot equality can support rerender suppression

### 3. Add a process runner for backend commands

Changes:

- Add a small helper around `Process` for invoking `yabai`
- Capture stdout and stderr
- Treat non-zero exit status and decode failures as fetch errors

Verify:

- Helper can run local commands
- Errors surface cleanly to the caller

### 4. Implement `YabaiBackend`

Changes:

- Decode Yabai spaces JSON
- Decode Yabai windows JSON
- Reduce raw data to ordered `BackendSnapshot`
- Deduplicate apps per space

Verify:

- Empty spaces remain in output
- Apps are unique within a space
- Spaces are ordered by Mission Control index

### 5. Add renderer and snapshot store

Changes:

- Add `StatusBarRenderer` to convert snapshots into a compact string
- Add `SnapshotStore` to suppress identical renders

Verify:

- Repeated identical snapshots return no-op update decisions
- Render output matches the agreed text format

### 6. Add status bar controller and app controller

Changes:

- Add `StatusBarController` to own and update `NSStatusItem`
- Add `AppController` to select the backend, drive the initial refresh, and start the 5 second timer
- Keep the timer low-frequency and simple

Verify:

- Title updates after launch fetch
- Title stays unchanged when snapshots repeat

### 7. Add failure behavior for unavailable Yabai

Changes:

- If the initial fetch fails, render `yabai unavailable`
- If later refreshes fail after a successful render, keep the last known title

Verify:

- Fresh launch with unavailable Yabai shows the exact failure string
- Later transient failures do not clear the prior render

## File Plan

Expected files to add or change:

- `SpacesBar/SpacesBarApp.swift`
- `SpacesBar/*` new source files for models, backend, controller, renderer, and process helper
- `SpacesBar.xcodeproj/project.pbxproj`

The exact file split should stay pragmatic. No abstractions beyond what Milestone 1 needs.

## Test Strategy

Because the repo currently has no test target, the minimum verification loop is:

1. Build the app with `xcodebuild`
2. Launch locally and confirm menu bar behavior
3. Validate Yabai-backed rendering on a machine with Yabai configured
4. Validate unavailable-backend behavior on a machine without Yabai or with Yabai stopped

If adding tests is cheap without project churn, prioritize pure Swift tests for:

- snapshot equality behavior
- renderer formatting
- Yabai reduction logic using canned JSON fixtures

If test-target setup would dominate the work, defer it and rely on focused manual verification for this slice.

## Risks

- Yabai JSON fields may differ slightly from assumptions and require one adjustment pass
- Long status text may eventually need truncation or overflow rules, but that is out of scope for Milestone 1
- App naming from Yabai window data may be inconsistent across applications; bundle metadata resolution is deferred

## Out of Scope Follow-Ups

- icon loading and caching
- focused-space emphasis
- event bridge
- backend availability checks beyond fetch failure
- config file parsing
- AeroSpace backend
- overflow handling
- richer diagnostics
