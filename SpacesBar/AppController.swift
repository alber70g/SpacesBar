import Foundation

@MainActor
final class AppController {
    private let backend: any Backend
    private let configStore = AppConfigStore()
    private let snapshotStore = SnapshotStore()
    private let statusBarController = StatusBarController()
    private let iconCache = IconCache()
    private let eventBridge = YabaiEventBridge()
    private var renderOptions = StatusBarRenderOptions()

    private var refreshTimer: Timer?
    private var isRefreshing = false

    init(backend: any Backend = BackendSelector.selectStartupBackend()) {
        self.backend = backend
        configStore.load()
        renderOptions.hideEmptySpaces = configStore.config.hideEmptySpaces
        renderOptions.iconStyle = configStore.config.iconStyle

        statusBarController.onToggleHideEmptySpaces = { [weak self] hideEmptySpaces in
            self?.updateHideEmptySpaces(hideEmptySpaces)
        }
        statusBarController.onSelectIconStyle = { [weak self] iconStyle in
            self?.updateIconStyle(iconStyle)
        }
    }

    func start() {
        AppLogger.shared.log("SpacesBar launch")
        statusBarController.install(config: configStore.config)
        refresh()
        startRefreshTimer()
        eventBridge.start { [weak self] in
            self?.refresh()
        }
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: configStore.config.refreshFallbackSeconds,
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

                    AppLogger.shared.log("Refresh success: \(snapshot.spaces.count) spaces")

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

                    AppLogger.shared.log("Refresh failed: \(error.localizedDescription)")

                    self.isRefreshing = false
                }
            }
        }
    }

    private func updateHideEmptySpaces(_ hideEmptySpaces: Bool) {
        renderOptions.hideEmptySpaces = hideEmptySpaces
        configStore.update { $0.hideEmptySpaces = hideEmptySpaces }

        guard let snapshot = snapshotStore.snapshot else {
            return
        }

        showSnapshot(snapshot)
    }

    private func updateIconStyle(_ iconStyle: IconStyle) {
        renderOptions.iconStyle = iconStyle
        configStore.update { $0.iconStyle = iconStyle }

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
