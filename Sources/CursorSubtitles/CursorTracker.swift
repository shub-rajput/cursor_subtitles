import AppKit

@MainActor
final class CursorTracker {
    private var timer: Timer?
    private let viewModel: SubtitleViewModel

    init(viewModel: SubtitleViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            MainActor.assumeIsolated {
                let mouseLocation = NSEvent.mouseLocation
                if let screen = NSScreen.main {
                    let flippedY = screen.frame.height - mouseLocation.y
                    self.viewModel.cursorPosition = NSPoint(x: mouseLocation.x, y: flippedY)
                }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
