import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var currentTitle = "Loading..."
    var onToggleHideEmptySpaces: ((Bool) -> Void)?
    private weak var hideEmptySpacesItem: NSMenuItem?

    func install(hideEmptySpaces: Bool) {
        let menu = NSMenu()
        let hideEmptySpacesItem = NSMenuItem(
            title: "Hide Empty Spaces",
            action: #selector(toggleHideEmptySpaces),
            keyEquivalent: ""
        )
        hideEmptySpacesItem.target = self
        hideEmptySpacesItem.state = hideEmptySpaces ? .on : .off

        let copyItem = NSMenuItem(
            title: "Copy Current Output",
            action: #selector(copyCurrentOutput),
            keyEquivalent: "c"
        )
        copyItem.target = self

        menu.addItem(hideEmptySpacesItem)
        menu.addItem(.separator())
        menu.addItem(copyItem)
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit SpacesBar",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        statusItem.menu = menu
        statusItem.button?.title = currentTitle
        statusItem.button?.toolTip = currentTitle
        self.hideEmptySpacesItem = hideEmptySpacesItem
    }

    func show(title: String) {
        currentTitle = title
        statusItem.button?.image = nil
        statusItem.button?.attributedTitle = NSAttributedString(string: title)
        statusItem.button?.title = title
        statusItem.button?.toolTip = title
    }

    func show(presentation: StatusBarPresentation) {
        currentTitle = presentation.plainText
        statusItem.button?.image = nil
        statusItem.button?.title = ""
        statusItem.button?.attributedTitle = presentation.attributedTitle
        statusItem.button?.toolTip = presentation.plainText
    }

    @objc
    private func copyCurrentOutput() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentTitle, forType: .string)
    }

    @objc
    private func toggleHideEmptySpaces() {
        guard let hideEmptySpacesItem else {
            return
        }

        let nextState: NSControl.StateValue = hideEmptySpacesItem.state == .on ? .off : .on
        hideEmptySpacesItem.state = nextState
        onToggleHideEmptySpaces?(nextState == .on)
    }
}
