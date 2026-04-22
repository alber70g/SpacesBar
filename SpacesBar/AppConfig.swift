import Foundation

enum IconStyle: String, Codable, CaseIterable, Sendable {
    case colored
    case monochrome

    var menuTitle: String {
        switch self {
        case .colored:
            "Colored"
        case .monochrome:
            "Monochrome"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "colored", "native", "template":
            self = .colored
        case "monochrome", "softMono":
            self = .monochrome
        default:
            self = .colored
        }
    }
}

struct AppConfig: Codable, Equatable, Sendable {
    var hideEmptySpaces: Bool
    var iconStyle: IconStyle
    var refreshFallbackSeconds: TimeInterval

    static let `default` = AppConfig(
        hideEmptySpaces: false,
        iconStyle: .colored,
        refreshFallbackSeconds: 5
    )

    var validated: AppConfig {
        AppConfig(
            hideEmptySpaces: hideEmptySpaces,
            iconStyle: iconStyle,
            refreshFallbackSeconds: max(1, refreshFallbackSeconds)
        )
    }
}

@MainActor
final class AppConfigStore {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private(set) var config = AppConfig.default

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() {
        do {
            try AppPaths.ensureParentDirectoriesExist()

            guard FileManager.default.fileExists(atPath: AppPaths.configFileURL.path) else {
                try save(config)
                return
            }

            let data = try Data(contentsOf: AppPaths.configFileURL)
            config = try decoder.decode(AppConfig.self, from: data).validated
        } catch {
            AppLogger.shared.log("Config load failed: \(error.localizedDescription)")
            config = AppConfig.default
        }
    }

    func update(_ mutate: (inout AppConfig) -> Void) {
        var nextConfig = config
        mutate(&nextConfig)
        nextConfig = nextConfig.validated

        guard nextConfig != config else {
            return
        }

        config = nextConfig

        do {
            try save(nextConfig)
            AppLogger.shared.log("Config saved to \(AppPaths.configFileURL.path)")
        } catch {
            AppLogger.shared.log("Config save failed: \(error.localizedDescription)")
        }
    }

    private func save(_ config: AppConfig) throws {
        try AppPaths.ensureParentDirectoriesExist()
        let data = try encoder.encode(config)
        try data.write(to: AppPaths.configFileURL, options: .atomic)
    }
}
