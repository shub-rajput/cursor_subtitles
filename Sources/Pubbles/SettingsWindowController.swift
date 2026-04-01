import AppKit
import SwiftUI

@MainActor
class SettingsWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 550),
            styleMask: [.titled, .closable, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pubbles"
        let toolbar = NSToolbar()
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView())
        self.init(window: window)
        window.delegate = self
    }

    func showWindow(tab: SettingsTab? = nil) {
        if let tab { SettingsNavigation.shared.selectedTab = tab }
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
