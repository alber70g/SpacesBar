import AppKit
import UniformTypeIdentifiers

@MainActor
final class IconCache {
    private var imagesByKey: [String: NSImage] = [:]

    func icon(for app: AppSnapshot, pointSize: CGFloat) -> NSImage {
        let key = "\(app.deduplicationKey)|size:\(Int(pointSize.rounded()))"
        if let cachedImage = imagesByKey[key] {
            return cachedImage
        }

        let resolvedImage = resolvedIcon(for: app)
        let icon = preparedIcon(from: resolvedImage, pointSize: pointSize)
        imagesByKey[key] = icon
        return icon
    }

    private func resolvedIcon(for app: AppSnapshot) -> NSImage {
        if let pid = app.pid,
           let runningApplication = NSRunningApplication(processIdentifier: pid_t(pid)),
           let image = runningApplication.icon {
            return image
        }

        if let bundlePath = app.bundlePath, !bundlePath.isEmpty {
            return NSWorkspace.shared.icon(forFile: bundlePath)
        }

        if let bundleID = app.bundleID,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        return NSWorkspace.shared.icon(for: .application)
    }

    private func preparedIcon(from image: NSImage, pointSize: CGFloat) -> NSImage {
        let icon = (image.copy() as? NSImage) ?? image
        icon.isTemplate = false
        icon.size = NSSize(width: pointSize, height: pointSize)
        return icon
    }
}
