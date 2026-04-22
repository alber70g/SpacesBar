import Foundation

@MainActor
final class SnapshotStore {
    private var lastSnapshot: BackendSnapshot?

    var hasSnapshot: Bool {
        lastSnapshot != nil
    }

    var snapshot: BackendSnapshot? {
        lastSnapshot
    }

    func consume(_ snapshot: BackendSnapshot) -> Bool {
        guard lastSnapshot != snapshot else {
            return false
        }

        lastSnapshot = snapshot
        return true
    }
}
