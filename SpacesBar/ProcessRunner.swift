import Foundation

enum ProcessRunner {
    static func run(executableName: String, arguments: [String]) async throws -> Data {
        let executableURL = try resolveExecutableURL(named: executableName)
        return try await run(executableURL: executableURL, arguments: arguments)
    }

    private static func run(executableURL: URL, arguments: [String]) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let standardOutput = Pipe()
            let standardError = Pipe()

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = standardOutput
            process.standardError = standardError

            process.terminationHandler = { process in
                let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
                let errorData = standardError.fileHandleForReading.readDataToEndOfFile()

                guard process.terminationStatus == 0 else {
                    let errorOutput = String(decoding: errorData, as: UTF8.self)
                    continuation.resume(throwing:
                        ProcessRunnerError.commandFailed(
                            executable: executableURL.path,
                            arguments: arguments,
                            output: errorOutput
                        )
                    )
                    return
                }

                continuation.resume(returning: outputData)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func resolveExecutableURL(named executableName: String) throws -> URL {
        let fileManager = FileManager.default
        let preferredLocations = [
            "/opt/homebrew/bin/\(executableName)",
            "/usr/local/bin/\(executableName)",
            "/usr/bin/\(executableName)"
        ]

        for candidate in preferredLocations where fileManager.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }

        let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for component in environmentPath.split(separator: ":") {
            let candidate = "\(component)/\(executableName)"
            if fileManager.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }

        throw ProcessRunnerError.executableNotFound(executableName)
    }
}

enum ProcessRunnerError: LocalizedError {
    case executableNotFound(String)
    case commandFailed(executable: String, arguments: [String], output: String)

    var errorDescription: String? {
        switch self {
        case let .executableNotFound(executableName):
            return "\(executableName) not found"
        case let .commandFailed(executable, arguments, output):
            let command = ([executable] + arguments).joined(separator: " ")
            if output.isEmpty {
                return "Command failed: \(command)"
            }

            return "Command failed: \(command) (\(output.trimmingCharacters(in: .whitespacesAndNewlines)))"
        }
    }
}
