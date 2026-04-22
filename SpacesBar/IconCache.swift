import AppKit
import UniformTypeIdentifiers

@MainActor
final class IconCache {
    private static let supersampleScale: CGFloat = 2

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
        let size = NSSize(width: pointSize, height: pointSize)
        let supersampledSize = NSSize(
            width: pointSize * Self.supersampleScale,
            height: pointSize * Self.supersampleScale
        )
        let supersampledRect = NSRect(origin: .zero, size: supersampledSize)

        let supersampledIcon = NSImage(size: supersampledSize)
        supersampledIcon.isTemplate = false
        supersampledIcon.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        if let representation = image.bestRepresentation(
            for: supersampledRect,
            context: NSGraphicsContext.current,
            hints: nil
        ) {
            representation.draw(in: supersampledRect)
        } else {
            image.draw(
                in: supersampledRect,
                from: .zero,
                operation: .copy,
                fraction: 1
            )
        }

        supersampledIcon.unlockFocus()

        let icon = NSImage(size: size)
        icon.isTemplate = false

        icon.lockFocus()
        defer { icon.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high
        supersampledIcon.draw(
            in: NSRect(origin: .zero, size: size),
            from: supersampledRect,
            operation: .copy,
            fraction: 1
        )

        return icon
    }
}
