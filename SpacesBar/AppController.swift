import Foundation

@MainActor
final class AppController {
    private let backend: any Backend
    private let snapshotStore = SnapshotStore()
    private let statusBarController = StatusBarController()
    private let iconCache = IconCache()
    private var renderOptions = StatusBarRenderOptions()

    private var refreshTimer: Timer?
    private var isRefreshing = false

    init(backend: any Backend = BackendSelector.selectStartupBackend()) {
        self.backend = backend
        statusBarController.onToggleHideEmptySpaces = { [weak self] hideEmptySpaces in
            self?.updateHideEmptySpaces(hideEmptySpaces)
        }
    }

    func start() {
        statusBarController.install(hideEmptySpaces: renderOptions.hideEmptySpaces)
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
                        self.showSnapshot(snapshot)
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

    private func updateHideEmptySpaces(_ hideEmptySpaces: Bool) {
        renderOptions.hideEmptySpaces = hideEmptySpaces

        guard let snapshot = snapshotStore.snapshot else {
            return
        }

        showSnapshot(snapshot)
    }

    private func showSnapshot(_ snapshot: BackendSnapshot) {
        let presentation = StatusBarRenderer.render(
            snapshot,
            iconCache: iconCache,
            options: renderOptions
        )
        statusBarController.show(presentation: presentation)
    }
}
