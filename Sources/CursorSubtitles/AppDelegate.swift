import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenubar()
    }

    private func setupMenubar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bubble.left.fill", accessibilityDescription: "Cursor Subtitles")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Subtitles", action: #selector(toggleSubtitles), keyEquivalent: "/"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func toggleSubtitles() {
        print("Toggle subtitles")
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
