import AppKit
import Foundation

struct YabaiBackend: Backend {
    nonisolated let id = "yabai"

    nonisolated init() {}

    nonisolated func fetchSnapshot() async throws -> BackendSnapshot {
        async let spacesData = ProcessRunner.run(executableName: "yabai", arguments: ["-m", "query", "--spaces"])
        async let windowsData = ProcessRunner.run(executableName: "yabai", arguments: ["-m", "query", "--windows"])

        let decoder = JSONDecoder()
        let spaces = try decoder.decode([YabaiSpace].self, from: try await spacesData)
        let windows = try decoder.decode([YabaiWindow].self, from: try await windowsData)

        let windowsBySpaceIndex = Dictionary(grouping: windows.compactMap(reduceWindow), by: \.spaceIndex)
        let focusedSpaceID = spaces.first(where: \.hasFocus)?.id.description

        let reducedSpaces = spaces
            .sorted { $0.index < $1.index }
            .map { space in
                let apps = deduplicatedApps(from: windowsBySpaceIndex[space.index] ?? [])
                return SpaceSnapshot(
                    id: String(space.id),
                    displayLabel: String(space.index),
                    isFocused: space.hasFocus,
                    apps: apps
                )
            }

        return BackendSnapshot(
            focusedSpaceID: focusedSpaceID,
            spaces: reducedSpaces
        )
    }

    nonisolated private func deduplicatedApps(from windows: [ReducedWindow]) -> [AppSnapshot] {
        var appsByKey: [String: AppSnapshot] = [:]

        for window in windows {
            let key = window.app.deduplicationKey

            if let existing = appsByKey[key] {
                appsByKey[key] = AppSnapshot(
                    bundleID: existing.bundleID,
                    pid: existing.pid,
                    displayName: existing.displayName,
                    bundlePath: existing.bundlePath,
                    isFocused: existing.isFocused || window.app.isFocused
                )
            } else {
                appsByKey[key] = window.app
            }
        }

        return appsByKey.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    nonisolated private func reduceWindow(_ window: YabaiWindow) -> ReducedWindow? {
        guard let spaceIndex = window.space else {
            return nil
        }

        let runningApplication = window.pid.flatMap { NSRunningApplication(processIdentifier: pid_t($0)) }
        let displayName = runningApplication?.localizedName ?? window.app?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let displayName, !displayName.isEmpty else {
            return nil
        }

        let app = AppSnapshot(
            bundleID: runningApplication?.bundleIdentifier,
            pid: window.pid,
            displayName: displayName,
            bundlePath: runningApplication?.bundleURL?.path,
            isFocused: window.hasFocus
        )

        return ReducedWindow(spaceIndex: spaceIndex, app: app)
    }
}

private struct ReducedWindow {
    let spaceIndex: Int
    let app: AppSnapshot
}

private struct YabaiSpace: Decodable {
    let id: Int
    let index: Int
    let hasFocus: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case index
        case hasFocus = "has-focus"
    }
}

private struct YabaiWindow: Decodable {
    let app: String?
    let hasFocus: Bool
    let pid: Int?
    let space: Int?

    enum CodingKeys: String, CodingKey {
        case app
        case hasFocus = "has-focus"
        case pid
        case space
    }
}
