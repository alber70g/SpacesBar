import AppKit
import CoreImage
import UniformTypeIdentifiers

@MainActor
final class IconCache {
    private static let supersampleScale: CGFloat = 2
    private static let focusedIconScale: CGFloat = 0.85
    private static let focusedDotDiameter: CGFloat = 3
    private static let focusedDotBottomInset: CGFloat = 1
    private static let focusedIconTopInset: CGFloat = 3

    private var imagesByKey: [String: NSImage] = [:]
    private let ciContext = CIContext(options: nil)

    func icon(for app: AppSnapshot, pointSize: CGFloat, style: IconStyle) -> NSImage {
        let appearanceName = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])?.rawValue ?? "default"
        let key = "\(app.deduplicationKey)|size:\(Int(pointSize.rounded()))|style:\(style.rawValue)|appearance:\(appearanceName)|focused:\(app.isFocused)"
        if let cachedImage = imagesByKey[key] {
            return cachedImage
        }

        let resolvedImage = resolvedIcon(for: app)
        let styledImage = styledIcon(from: resolvedImage, style: style)
        let icon = preparedIcon(from: styledImage, pointSize: pointSize)
        let finalImage = app.isFocused ? decoratedFocusedIcon(from: icon, pointSize: pointSize) : icon
        imagesByKey[key] = finalImage
        return finalImage
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

    private func styledIcon(from image: NSImage, style: IconStyle) -> NSImage {
        switch style {
        case .colored:
            return image
        case .monochrome:
            return softMonochromeIcon(from: image)
        }
    }

    private func softMonochromeIcon(from image: NSImage) -> NSImage {
        guard
            let data = image.tiffRepresentation,
            let ciImage = CIImage(data: data)
        else {
            return image
        }

        let grayscale = ciImage.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0,
            kCIInputContrastKey: 0.9,
            kCIInputBrightnessKey: 0.05
        ])

        let resolvedTint = softMonochromeTintColor()
        let monochrome = grayscale.applyingFilter("CIColorMonochrome", parameters: [
            kCIInputColorKey: CIColor(color: resolvedTint) as Any,
            kCIInputIntensityKey: 0.72
        ])

        guard let cgImage = ciContext.createCGImage(monochrome, from: monochrome.extent) else {
            return image
        }

        return NSImage(cgImage: cgImage, size: image.size)
    }

    private func softMonochromeTintColor() -> NSColor {
        let appearance = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])

        switch appearance {
        case .darkAqua:
            return NSColor(calibratedWhite: 0.88, alpha: 0.92)
        default:
            return NSColor(calibratedWhite: 0.20, alpha: 0.78)
        }
    }

    private func decoratedFocusedIcon(from image: NSImage, pointSize: CGFloat) -> NSImage {
        let canvasSize = NSSize(width: pointSize, height: pointSize)
        let focusedIconSize = pointSize * Self.focusedIconScale
        let origin = NSPoint(
            x: (pointSize - focusedIconSize) / 2,
            y: Self.focusedDotDiameter + Self.focusedDotBottomInset + Self.focusedIconTopInset
        )

        let focusedImage = NSImage(size: canvasSize)
        focusedImage.lockFocus()
        defer { focusedImage.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: origin, size: NSSize(width: focusedIconSize, height: focusedIconSize)),
            from: .zero,
            operation: .copy,
            fraction: 1
        )

        let dotColor = NSColor.labelColor
        dotColor.setFill()
        let dotRect = NSRect(
            x: (pointSize - Self.focusedDotDiameter) / 2,
            y: Self.focusedDotBottomInset,
            width: Self.focusedDotDiameter,
            height: Self.focusedDotDiameter
        )
        NSBezierPath(ovalIn: dotRect).fill()

        return focusedImage
    }
}
