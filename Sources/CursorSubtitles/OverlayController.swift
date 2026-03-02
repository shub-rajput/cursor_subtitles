import AppKit
import SwiftUI

@MainActor
class OverlayController {
    private var window: OverlayWindow?
    private let viewModel: SubtitleViewModel

    init(viewModel: SubtitleViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        if window == nil {
            window = OverlayWindow()
            let hostingView = NSHostingView(rootView: PillContainerView(viewModel: viewModel))
            hostingView.frame = window!.contentRect(forFrameRect: window!.frame)
            hostingView.autoresizingMask = [.width, .height]
            window!.contentView = hostingView
        }
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }
}
