import AppKit
import SwiftUI
import Combine

@MainActor
class OverlayController {
    private var windows: [ObjectIdentifier: OverlayWindow] = [:]
    private let viewModel: SubtitleViewModel
    private var cancellables = Set<AnyCancellable>()

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

        // When drawing mode is on and pill is active, overlay absorbs clicks
        // (blocks apps below but screenshot tools at higher levels still work)
        Publishers.CombineLatest(viewModel.$isActive, viewModel.$drawingModeEnabled)
            .sink { [weak self] isActive, drawingEnabled in
                MainActor.assumeIsolated {
                    let shouldBlock = isActive && drawingEnabled
                    self?.windows.values.forEach { $0.ignoresMouseEvents = !shouldBlock }
                }
            }
            .store(in: &cancellables)
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
