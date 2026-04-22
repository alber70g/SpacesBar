import Foundation

protocol Backend: Sendable {
    nonisolated var id: String { get }
    nonisolated func fetchSnapshot() async throws -> BackendSnapshot
}

enum BackendSelector {
    nonisolated static func selectStartupBackend() -> any Backend {
        YabaiBackend()
    }
}
