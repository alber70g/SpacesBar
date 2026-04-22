import Foundation

enum StatusBarRenderer {
    nonisolated static func render(_ snapshot: BackendSnapshot) -> String {
        snapshot.spaces
            .map(renderSpace)
            .joined(separator: " | ")
    }

    nonisolated private static func renderSpace(_ space: SpaceSnapshot) -> String {
        let appSegments = space.apps.map { "[\($0.displayName)]" }
        let segments = [space.displayLabel] + appSegments
        return segments.joined(separator: " ")
    }
}
