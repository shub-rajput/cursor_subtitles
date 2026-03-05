import Foundation
import AppKit

@MainActor
class SubtitleViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var isActive: Bool = false
    @Published var cursorPosition: NSPoint = .zero
    @Published var activeScreenID: ObjectIdentifier?
    @Published var isVisible: Bool = false

    /// The previous line shown above, fading out when user starts typing on the new line
    @Published var previousLine: String = ""
    @Published var showPreviousLine: Bool = false
    /// Whether cursor is on a new blank line (Enter pressed, haven't typed yet)
    @Published var onNewLine: Bool = false

    @Published var drawingModeEnabled: Bool = false
    @Published var strokes: [[NSPoint]] = []
    /// Not @Published — updated at ~60Hz during drag; Canvas reads it via TimelineView to avoid PillView redraws
    var currentStroke: [NSPoint] = []
    @Published var isDrawing: Bool = false

    var config: ConfigManager { ConfigManager.shared }

    var displayText: String {
        if text.isEmpty && !onNewLine { return config.config.style.placeholderText }
        return text
    }

    var isPlaceholder: Bool { text.isEmpty && !onNewLine && isActive }

    private var idleTimer: Timer?

    func resetIdleTimer() {
        idleTimer?.invalidate()
        isVisible = true
        let timeout = config.config.behavior.idleTimeout
        idleTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.dismiss()
            }
        }
    }

    func activate() {
        text = ""
        previousLine = ""
        showPreviousLine = false
        onNewLine = false
        isShowingDrawingHint = false
        isActive = true
        isVisible = true
        resetIdleTimer()
    }

    func dismiss() {
        idleTimer?.invalidate()
        isActive = false
        isVisible = false
        // Delay content clearing so the fade animation renders with current appearance intact
        let fadeOut = config.config.behavior.fadeOutDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut) { [weak self] in
            guard let self else { return }
            self.text = ""
            self.previousLine = ""
            self.showPreviousLine = false
            self.onNewLine = false
            self.isShowingDrawingHint = false
            self.clearStrokes()
        }
    }

    private var isShowingDrawingHint = false

    private func ensureActiveScreen() {
        if activeScreenID == nil,
           let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main {
            activeScreenID = ObjectIdentifier(screen)
        }
    }

    private func showTemporaryPill(text: String, timeout: TimeInterval) {
        ensureActiveScreen()
        self.text = text
        onNewLine = false
        isActive = true
        isVisible = true
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.dismiss() }
        }
    }

    func showDrawingModeHint(enabled: Bool) {
        let hintText = enabled ? "Drawing on" : "Drawing off"

        // If pill is active, only update if currently showing a hint (don't overwrite user text)
        if isActive {
            guard isShowingDrawingHint else { return }
            text = hintText
            idleTimer?.invalidate()
            idleTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
                DispatchQueue.main.async { self?.dismiss() }
            }
            return
        }

        isShowingDrawingHint = true
        showTemporaryPill(text: hintText, timeout: 3)
    }

    func showOnboarding() {
        ensureActiveScreen()
        previousLine = "Hey! Press ⌘/ to enable Pubbles"
        showPreviousLine = true
        showTemporaryPill(text: "Check the menubar for more settings!", timeout: 10)
    }

    func handleCharacter(_ char: String) {
        guard isActive else { return }
        if !isVisible { isVisible = true }

        // Clear hint text when user starts typing
        if isShowingDrawingHint {
            isShowingDrawingHint = false
            text = ""
        }

        // If we're on a new line and start typing, fade out the previous line
        if onNewLine && showPreviousLine {
            showPreviousLine = false
        }
        onNewLine = false

        if text.count < config.config.behavior.charLimit {
            text += char
        }
        resetIdleTimer()
    }

    func handleNewline() {
        guard isActive else { return }
        if !isVisible { isVisible = true }

        // Move current text to previous line, show it above
        if !text.isEmpty {
            previousLine = text
            showPreviousLine = true
            text = ""
            onNewLine = true
        }
        resetIdleTimer()
    }

    func handleBackspace() {
        guard isActive, !text.isEmpty else { return }
        text.removeLast()
        resetIdleTimer()
    }

    func startStroke(at point: NSPoint) {
        guard isActive, drawingModeEnabled else { return }
        currentStroke = [point]
        isDrawing = true
    }

    func continueStroke(to point: NSPoint) {
        guard isActive, drawingModeEnabled, !currentStroke.isEmpty else { return }
        currentStroke.append(point)
        resetIdleTimer()
    }

    func endStroke() {
        guard !currentStroke.isEmpty else { return }
        strokes.append(currentStroke)
        currentStroke = []
        isDrawing = false
        resetIdleTimer()
    }

    func clearStrokes() {
        strokes = []
        currentStroke = []
    }
}
