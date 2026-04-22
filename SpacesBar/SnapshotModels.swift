import Foundation

struct BackendSnapshot: Equatable, Sendable {
    let focusedSpaceID: String?
    let spaces: [SpaceSnapshot]
}

struct SpaceSnapshot: Equatable, Sendable {
    let id: String
    let displayLabel: String
    let isFocused: Bool
    let apps: [AppSnapshot]
}

struct AppSnapshot: Equatable, Hashable, Sendable {
    let bundleID: String?
    let pid: Int?
    let displayName: String
    let bundlePath: String?
}

extension AppSnapshot {
    nonisolated var deduplicationKey: String {
        if let bundleID {
            return "bundle-id:\(bundleID)"
        }

        if let bundlePath {
            return "bundle-path:\(bundlePath)"
        }

        if let pid {
            return "pid:\(pid):\(displayName)"
        }

        return "name:\(displayName)"
    }
}
