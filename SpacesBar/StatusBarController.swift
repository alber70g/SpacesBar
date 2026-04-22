import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var currentTitle = "Loading..."

    func install() {
        let menu = NSMenu()
        let copyItem = NSMenuItem(
            title: "Copy Current Output",
            action: #selector(copyCurrentOutput),
            keyEquivalent: "c"
        )
        copyItem.target = self

        menu.addItem(copyItem)
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit SpacesBar",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        statusItem.menu = menu
        statusItem.button?.title = currentTitle
    }

    func show(title: String) {
        currentTitle = title
        statusItem.button?.title = title
    }

    @objc
    private func copyCurrentOutput() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentTitle, forType: .string)
    }
}
