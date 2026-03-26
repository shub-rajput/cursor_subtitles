import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let viewModel = SubtitleViewModel()
    private var overlayController: OverlayController!
    private var eventManager: EventManager!
    private var cursorTracker: CursorTracker!
    private var isEnabled = true
    private var settingsWindowController: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlayController = OverlayController(viewModel: viewModel)
        eventManager = EventManager(viewModel: viewModel)
        cursorTracker = CursorTracker(viewModel: viewModel)

        setupMenubar()
        settingsWindowController = SettingsWindowController()
        settingsWindowController.showWindow()
        overlayController.show()
        eventManager.start()
        cursorTracker.start()

        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.viewModel.showOnboarding()
            }
        }

        UpdateChecker.shared.onUpdateStatusChanged = { [weak self] in
            self?.statusItem.menu = self?.buildMenu()
        }
        UpdateChecker.shared.checkForUpdates()
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

        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let hotkey = ConfigManager.shared.config.hotkey
        let hint = NSMenuItem(title: "\(hotkey) to start typing", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.state = isEnabled ? .on : .off
        menu.addItem(toggleItem)

        let drawingItem = NSMenuItem(title: "Drawing", action: #selector(toggleDrawingAllowed), keyEquivalent: "")
        drawingItem.state = viewModel.drawingAllowed ? .on : .off
        menu.addItem(drawingItem)
        menu.addItem(NSMenuItem.separator())

        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = buildThemeMenu()
        menu.addItem(themeItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        return menu
    }

    private func buildThemeMenu() -> NSMenu {
        let submenu = NSMenu()
        let currentTheme = ConfigManager.shared.config.theme

        let defaultItem = NSMenuItem(title: "Default", action: nil, keyEquivalent: "")
        defaultItem.state = currentTheme == nil ? .on : .off
        defaultItem.submenu = buildColorMenu()
        submenu.addItem(defaultItem)
        submenu.addItem(NSMenuItem.separator())

        let themes = ConfigManager.shared.availableThemes()
        for theme in themes {
            let item = NSMenuItem(title: theme.name, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.representedObject = theme.filename
            item.state = currentTheme == theme.filename ? .on : .off
            submenu.addItem(item)
        }

        submenu.addItem(NSMenuItem.separator())
        submenu.addItem(NSMenuItem(title: "Open Themes Folder", action: #selector(openThemesFolder), keyEquivalent: ""))

        return submenu
    }

    private func buildColorMenu() -> NSMenu {
        let submenu = NSMenu()
        let colors: [(String, String)] = [
            ("Blue", "#256CEF"),
            ("Red", "#991B1B"),
            ("Green", "#16A34A"),
            ("Yellow", "#E6AE00"),
            ("Pink", "#DB2777"),
            ("Purple", "#7C3AED"),
            ("Orange", "#D97706"),
            ("Slate", "#0F172A"),
        ]
        let currentColor = ConfigManager.shared.config.style.backgroundColor.uppercased()
        for (name, hex) in colors {
            let item = NSMenuItem(title: name, action: #selector(selectColor(_:)), keyEquivalent: "")
            item.representedObject = hex
            item.state = currentColor == hex.uppercased() ? .on : .off
            submenu.addItem(item)
        }
        return submenu
    }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        let themeName = sender.representedObject as? String
        ConfigManager.shared.setTheme(themeName)
        statusItem.menu = buildMenu()
    }

    @objc private func selectColor(_ sender: NSMenuItem) {
        guard let hex = sender.representedObject as? String else { return }
        ConfigManager.shared.setTheme(nil)
        ConfigManager.shared.setColor(hex)
        statusItem.menu = buildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        let hotkey = ConfigManager.shared.config.hotkey
        menu.items.first(where: { $0.title.hasSuffix("to start typing") })?.title = "\(hotkey) to start typing"
        menu.items.first(where: { $0.title == "Enabled" })?.state = isEnabled ? .on : .off
        menu.items.first(where: { $0.title == "Drawing" })?.state = viewModel.drawingAllowed ? .on : .off

        if let themeItem = menu.items.first(where: { $0.title == "Theme" }) {
            themeItem.submenu = buildThemeMenu()
        }
    }

    @objc private func toggleDrawingAllowed() {
        viewModel.drawingAllowed.toggle()
        if !viewModel.drawingAllowed {
            viewModel.drawingModeEnabled = false
            viewModel.drawingToggleActive = false
        }
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

    @objc private func resetConfig() {
        ConfigManager.shared.resetStyleOverrides()
        statusItem.menu = buildMenu()
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config/pubbles/config.json")
        )
    }

    @objc private func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let alert = NSAlert()
        alert.messageText = "Pubbles"
        alert.informativeText = "Version \(version)\n\nSubtitles for your pointer.\n\nCopyright © 2026 Shubhang Haresh Rajput"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Support Pubbles ♥")
        alert.addButton(withTitle: "GitHub")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://ko-fi.com/shubhangrajput")!)
        } else if response == .alertThirdButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/shub-rajput/pubbles")!)
        }
    }

    @objc private func openThemesFolder() {
        let themesURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/pubbles/themes")
        NSWorkspace.shared.open(themesURL)
    }

    @objc private func showKeyboardShortcuts() {
        let hotkey = ConfigManager.shared.config.hotkey
        let alert = NSAlert()
        alert.messageText = "Hotkeys"
        alert.informativeText = """
            \(hotkey) — Toggle Pubble pill
            Esc — Dismiss pill
            Enter — New line
            Backspace — Delete character

            While pill is active:
            Hold ⌘ + click+drag — Draw on screen
            ⌘↑ / ⌘↓ — Cycle themes
            ⌘→ / ⌘← — Scale pill up / down

            Click anywhere — Dismiss pill
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func checkForUpdates() {
        if UpdateChecker.shared.updateAvailable {
            UpdateChecker.shared.promptAndUpdate()
        } else {
            UpdateChecker.shared.checkForUpdates(silent: false)
        }
    }

    @objc private func openSettings() {
        settingsWindowController.showWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindowController.showWindow()
        return true
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
