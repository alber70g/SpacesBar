import Foundation

final class AppLogger {
    static let shared = AppLogger()

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {
        do {
            try AppPaths.ensureParentDirectoriesExist()
            if !FileManager.default.fileExists(atPath: AppPaths.logFileURL.path) {
                FileManager.default.createFile(atPath: AppPaths.logFileURL.path, contents: Data())
            }
        } catch {
            NSLog("SpacesBar logger init failed: \(error.localizedDescription)")
        }
    }

    func log(_ message: String) {
        let line = "\(dateFormatter.string(from: Date())) \(message)\n"

        do {
            let data = Data(line.utf8)
            let fileHandle = try FileHandle(forWritingTo: AppPaths.logFileURL)
            defer { try? fileHandle.close() }
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: data)
        } catch {
            NSLog("SpacesBar log write failed: \(error.localizedDescription)")
        }
    }
}
