import Foundation
import AppKit
import SwiftUI

struct AnimatedChar: Identifiable, Equatable {
    let id: Int
    let character: String
}

@MainActor
class SubtitleViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var isActive: Bool = false
    @Published var cursorPosition: NSPoint = .zero
    @Published var activeScreenID: ObjectIdentifier?
    @Published var isVisible: Bool = false

    /// The previous line shown above, fading out when user starts typing on the new line
    @Published var previousLine: String = ""
    @Published var previousLineChars: [AnimatedChar] = []
    @Published var showPreviousLine: Bool = false
    /// Whether cursor is on a new blank line (Enter pressed, haven't typed yet)
    @Published var onNewLine: Bool = false

    @Published var drawingAllowed: Bool = true
    @Published var drawingModeEnabled: Bool = false
    @Published var strokes: [[NSPoint]] = []
    /// Not @Published — updated at ~60Hz during drag; Canvas reads it via TimelineView to avoid PillView redraws
    var currentStroke: [NSPoint] = []
    @Published var isDrawing: Bool = false

    @Published var animatedChars: [AnimatedChar] = []
    private var nextCharID = 0

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
        animatedChars = []
        nextCharID = 0
        previousLine = ""
        previousLineChars = []
        showPreviousLine = false
        onNewLine = false
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
            self.animatedChars = []
            self.nextCharID = 0
            self.previousLine = ""
            self.previousLineChars = []
            self.showPreviousLine = false
            self.onNewLine = false
            self.clearStrokes()
        }
    }

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

    func showOnboarding() {
        previousLine = "Hey! Press ⌘/ to enable Pubbles"
        showPreviousLine = true
        showTemporaryPill(text: "Check the menubar for more settings!", timeout: 10)
    }

    func handleCharacter(_ char: String) {
        guard isActive else { return }
        if !isVisible { isVisible = true }

        // If we're on a new line and start typing, fade out the previous line
        if onNewLine && showPreviousLine {
            withAnimation(.snappy(duration: 0.2)) {
                showPreviousLine = false
            }
        }
        onNewLine = false

        if text.count < config.config.behavior.charLimit {
            text += char
            withAnimation(.spring(duration: 0.25, bounce: 0.1)) {
                for c in char {
                    animatedChars.append(AnimatedChar(id: nextCharID, character: String(c)))
                    nextCharID += 1
                }
            }
        }
        resetIdleTimer()
    }

    func handleNewline() {
        guard isActive else { return }
        if !isVisible { isVisible = true }

        // Move current text to previous line, show it above
        if !text.isEmpty {
            withAnimation(.snappy(duration: 0.2)) {
                previousLine = text
                previousLineChars = animatedChars
                showPreviousLine = true
                onNewLine = true
            }
            // Outside withAnimation so chars vanish instantly (no exit transition)
            text = ""
            animatedChars = []
        }
        resetIdleTimer()
    }

    func handleBackspace() {
        guard isActive, !text.isEmpty else { return }
        text.removeLast()
        withAnimation(.easeIn(duration: 0.15)) {
            if !animatedChars.isEmpty {
                animatedChars.removeLast()
            }
        }
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
