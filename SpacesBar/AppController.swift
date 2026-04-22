import Foundation

@MainActor
final class AppController {
    private let backend: any Backend
    private let snapshotStore = SnapshotStore()
    private let statusBarController = StatusBarController()

    private var refreshTimer: Timer?
    private var isRefreshing = false

    init(backend: any Backend = BackendSelector.selectStartupBackend()) {
        self.backend = backend
    }

    func start() {
        statusBarController.install()
        refresh()
        startRefreshTimer()
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 5,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    private func refresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        let backend = self.backend

        Task {
            do {
                let snapshot = try await backend.fetchSnapshot()
                await MainActor.run { [weak self] in
                    guard let self else {
                        return
                    }

                    if self.snapshotStore.consume(snapshot) {
                        let title = StatusBarRenderer.render(snapshot)
                        self.statusBarController.show(title: title)
                    }

                    self.isRefreshing = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else {
                        return
                    }

                    if !self.snapshotStore.hasSnapshot {
                        self.statusBarController.show(title: "yabai unavailable")
                    }

                    self.isRefreshing = false
                }
            }
        }
    }
}
