import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var currentTitle = "Loading..."
    var onToggleHideEmptySpaces: ((Bool) -> Void)?
    var onToggleMinimize: ((Bool) -> Void)?
    var onSelectIconStyle: ((IconStyle) -> Void)?
    private weak var hideEmptySpacesItem: NSMenuItem?
    private weak var minimizeItem: NSMenuItem?
    private var iconStyleItems: [IconStyle: NSMenuItem] = [:]

    func install(config: AppConfig) {
        let menu = NSMenu()
        let hideEmptySpacesItem = NSMenuItem(
            title: "Hide Empty Spaces",
            action: #selector(toggleHideEmptySpaces),
            keyEquivalent: ""
        )
        hideEmptySpacesItem.target = self
        hideEmptySpacesItem.state = config.hideEmptySpaces ? .on : .off

        let minimizeItem = NSMenuItem(
            title: "Minimize",
            action: #selector(toggleMinimize),
            keyEquivalent: ""
        )
        minimizeItem.target = self
        minimizeItem.state = config.minimize ? .on : .off

        let iconStyleItem = NSMenuItem(title: "Icon Style", action: nil, keyEquivalent: "")
        let iconStyleMenu = NSMenu()
        for style in IconStyle.allCases {
            let item = NSMenuItem(
                title: style.menuTitle,
                action: #selector(selectIconStyle(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = style.rawValue
            item.state = style == config.iconStyle ? .on : .off
            iconStyleMenu.addItem(item)
            iconStyleItems[style] = item
        }
        menu.setSubmenu(iconStyleMenu, for: iconStyleItem)

        let copyItem = NSMenuItem(
            title: "Copy Current Output",
            action: #selector(copyCurrentOutput),
            keyEquivalent: "c"
        )
        copyItem.target = self

        let githubItem = NSMenuItem(
            title: "View SpacesBar on GitHub",
            action: #selector(openGitHubRepository),
            keyEquivalent: ""
        )
        githubItem.target = self

        menu.addItem(hideEmptySpacesItem)
        menu.addItem(minimizeItem)
        menu.addItem(iconStyleItem)
        menu.addItem(.separator())
        menu.addItem(copyItem)
        menu.addItem(githubItem)
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
        self.minimizeItem = minimizeItem
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

    @objc
    private func toggleMinimize() {
        guard let minimizeItem else {
            return
        }

        let nextState: NSControl.StateValue = minimizeItem.state == .on ? .off : .on
        minimizeItem.state = nextState
        onToggleMinimize?(nextState == .on)
    }

    @objc
    private func selectIconStyle(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let selectedStyle = IconStyle(rawValue: rawValue)
        else {
            return
        }

        for (style, item) in iconStyleItems {
            item.state = style == selectedStyle ? .on : .off
        }

        onSelectIconStyle?(selectedStyle)
    }

    @objc
    private func openGitHubRepository() {
        guard let url = URL(string: "https://github.com/alber70g/spacesbar") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
