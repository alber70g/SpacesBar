import AppKit
import Foundation

struct StatusBarPresentation {
    let plainText: String
    let attributedTitle: NSAttributedString
}

enum StatusBarRenderer {
    private static let iconPointSize: CGFloat = 26
    private static let iconVerticalOffset: CGFloat = -8
    private static let focusedIconVerticalOffset: CGFloat = -11

    @MainActor
    static func render(
        _ snapshot: BackendSnapshot,
        iconCache: IconCache,
        options: StatusBarRenderOptions
    ) -> StatusBarPresentation {
        let spaces = visibleSpaces(in: snapshot, options: options)

        let plainText = spaces
            .map(renderPlainTextSpace)
            .joined(separator: "  ")

        let attributedTitle = NSMutableAttributedString()
        for (index, space) in spaces.enumerated() {
            if index > 0 {
                attributedTitle.append(
                    NSAttributedString(
                        string: "   ",
                        attributes: baseTextAttributes
                    )
                )
            }

            attributedTitle.append(
                NSAttributedString(
                    string: space.displayLabel,
                    attributes: textAttributes(for: space)
                )
            )

            guard !space.apps.isEmpty else {
                continue
            }

            attributedTitle.append(NSAttributedString(string: "  ", attributes: baseTextAttributes))

            for (appIndex, app) in space.apps.enumerated() {
                if appIndex > 0 {
                    attributedTitle.append(NSAttributedString(string: "  ", attributes: baseTextAttributes))
                }

                let attachment = NSTextAttachment()
                attachment.image = iconCache.icon(
                    for: app,
                    pointSize: iconPointSize,
                    style: options.iconStyle
                )
                attachment.bounds = NSRect(
                    x: 0,
                    y: app.isFocused ? focusedIconVerticalOffset : iconVerticalOffset,
                    width: iconPointSize,
                    height: iconPointSize
                )
                attributedTitle.append(NSAttributedString(attachment: attachment))
            }
        }

        return StatusBarPresentation(
            plainText: plainText,
            attributedTitle: attributedTitle
        )
    }

    nonisolated private static func visibleSpaces(
        in snapshot: BackendSnapshot,
        options: StatusBarRenderOptions
    ) -> [SpaceSnapshot] {
        guard options.hideEmptySpaces else {
            return snapshot.spaces
        }

        return snapshot.spaces.filter { !$0.apps.isEmpty || $0.isFocused }
    }

    nonisolated private static func renderPlainTextSpace(_ space: SpaceSnapshot) -> String {
        let appSegments = space.apps.map { "[\($0.displayName)]" }
        let segments = [space.displayLabel] + appSegments
        return segments.joined(separator: " ")
    }

    @MainActor
    private static var baseTextAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
    }

    @MainActor
    private static func textAttributes(for space: SpaceSnapshot) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedDigitSystemFont(
                ofSize: 13,
                weight: space.isFocused ? .semibold : .regular
            ),
            .foregroundColor: NSColor.labelColor,
            .underlineStyle: space.isFocused ? NSUnderlineStyle.single.rawValue : 0
        ]
    }
}
