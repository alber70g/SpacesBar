import Foundation

enum AppPaths {
    private static let fileManager = FileManager.default

    static var configDirectoryURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
    }

    static var configFileURL: URL {
        configDirectoryURL.appendingPathComponent("spacesbar.json")
    }

    static var applicationSupportDirectoryURL: URL {
        try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("SpacesBar", isDirectory: true)
    }

    static var refreshSignalFileURL: URL {
        applicationSupportDirectoryURL.appendingPathComponent("refresh.signal")
    }

    static var logsDirectoryURL: URL {
        try! fileManager.url(
            for: .libraryDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("Logs", isDirectory: true)
        .appendingPathComponent("SpacesBar", isDirectory: true)
    }

    static var logFileURL: URL {
        logsDirectoryURL.appendingPathComponent("spacesbar.log")
    }

    static func ensureParentDirectoriesExist() throws {
        try fileManager.createDirectory(at: configDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: applicationSupportDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
    }

    static func ensureRefreshSignalFileExists() throws {
        try ensureParentDirectoriesExist()

        if !fileManager.fileExists(atPath: refreshSignalFileURL.path) {
            fileManager.createFile(atPath: refreshSignalFileURL.path, contents: Data())
        }
    }
}
