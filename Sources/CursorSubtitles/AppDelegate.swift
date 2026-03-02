import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let viewModel = SubtitleViewModel()
    private var overlayController: OverlayController!
    private var eventManager: EventManager!
    private var cursorTracker: CursorTracker!
    private var isEnabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlayController = OverlayController(viewModel: viewModel)
        eventManager = EventManager(viewModel: viewModel)
        cursorTracker = CursorTracker(viewModel: viewModel)

        setupMenubar()
        overlayController.show()
        eventManager.start()
        cursorTracker.start()
    }

    private func setupMenubar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let iconPath = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png"),
               let icon = NSImage(contentsOfFile: iconPath) {
                icon.isTemplate = true
                icon.size = NSSize(width: 18, height: 18)
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: "Cursor Subtitles")
            }
        }

        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.state = .on
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Edit Config...", action: #selector(openConfig), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        if isEnabled {
            eventManager.start()
            overlayController.show()
            statusItem.menu?.item(at: 0)?.state = .on
        } else {
            viewModel.dismiss()
            eventManager.stop()
            overlayController.hide()
            statusItem.menu?.item(at: 0)?.state = .off
        }
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config/cursor-subtitles/config.json")
        )
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
