import AppKit
import SwiftUI

@MainActor
class SettingsWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pubbles"
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView())
        self.init(window: window)
        window.delegate = self
    }

    func showWindow() {
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
