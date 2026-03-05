import AppKit
import SwiftUI

@MainActor
class OverlayController {
    private var windows: [ObjectIdentifier: OverlayWindow] = [:]
    private let viewModel: SubtitleViewModel

    init(viewModel: SubtitleViewModel) {
        self.viewModel = viewModel
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncWindows()
            }
        }
    }

    func show() {
        syncWindows()
    }

    func hide() {
        for window in windows.values {
            window.orderOut(nil)
        }
    }

    var isVisible: Bool {
        windows.values.contains { $0.isVisible }
    }

    private func syncWindows() {
        let currentScreens = NSScreen.screens
        let currentKeys = Set(currentScreens.map { ObjectIdentifier($0) })
        let existingKeys = Set(windows.keys)

        // Remove windows for disconnected screens
        for key in existingKeys.subtracting(currentKeys) {
            windows[key]?.orderOut(nil)
            windows.removeValue(forKey: key)
        }

        // Add windows for new screens
        for screen in currentScreens {
            let key = ObjectIdentifier(screen)
            if windows[key] == nil {
                let window = OverlayWindow(for: screen)
                let hostingView = NSHostingView(rootView: PillContainerView(viewModel: viewModel, screenID: key))
                hostingView.frame = window.contentRect(forFrameRect: window.frame)
                hostingView.autoresizingMask = [.width, .height]
                window.contentView = hostingView
                window.orderFront(nil)
                windows[key] = window
            }
        }
    }
}
