import Dispatch
import Foundation

@MainActor
final class YabaiEventBridge {
    private var fileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?

    func start(onEvent: @escaping @MainActor () -> Void) {
        stop()

        do {
            try AppPaths.ensureRefreshSignalFileExists()
        } catch {
            AppLogger.shared.log("Event bridge setup failed: \(error.localizedDescription)")
            return
        }

        fileDescriptor = open(AppPaths.refreshSignalFileURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            AppLogger.shared.log("Event bridge open failed for \(AppPaths.refreshSignalFileURL.path)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.attrib, .delete, .extend, .link, .rename, .write],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler {
            Task { @MainActor in
                do {
                    try AppPaths.ensureRefreshSignalFileExists()
                } catch {
                    AppLogger.shared.log("Event bridge file recreation failed: \(error.localizedDescription)")
                }

                AppLogger.shared.log("Yabai signal refresh event")
                onEvent()
            }
        }

        source.setCancelHandler { [fileDescriptor] in
            if fileDescriptor >= 0 {
                close(fileDescriptor)
            }
        }

        self.source = source
        source.resume()
        AppLogger.shared.log("Event bridge watching \(AppPaths.refreshSignalFileURL.path)")
    }

    func stop() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }
}
