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
    @Published var pillHiddenForDrawing: Bool = false
    var drawingToggleActive: Bool = false
    private var activatedFromDrawingToggle: Bool = false
    @Published var strokes: [[NSPoint]] = []
    /// Not @Published — updated at ~60Hz during drag; Canvas reads it via TimelineView to avoid PillView redraws
    var currentStroke: [NSPoint] = []
    @Published var isDrawing: Bool = false

    @Published var dictationModeEnabled: Bool = false
    private var dictationBaseline: String = ""

    @Published var animatedChars: [AnimatedChar] = []
    private var nextCharID = 0
    /// Cursor position for arrow key editing (0 = before first char, text.count = end)
    @Published var textCursorIndex: Int = 0

    var config: ConfigManager { ConfigManager.shared }

    var displayText: String {
        if isListening && text.isEmpty { return "Listening…" }
        if text.isEmpty && !onNewLine { return config.config.style.placeholderText }
        return text
    }

    var isPlaceholder: Bool { text.isEmpty && !onNewLine && isActive }

    var isListening: Bool { dictationModeEnabled && isActive }

    /// ID of the char at cursor position (for overlay cursor placement), nil when cursor is at end
    var editingCharID: Int? {
        guard textCursorIndex < animatedChars.count else { return nil }
        return animatedChars[textCursorIndex].id
    }

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
        textCursorIndex = 0
        previousLine = ""
        previousLineChars = []
        showPreviousLine = false
        onNewLine = false
        isActive = true
        isVisible = true
        resetIdleTimer()
    }

    func showPubbleForDrawing() {
        guard drawingToggleActive else { return }
        text = ""
        animatedChars = []
        nextCharID = 0
        textCursorIndex = 0
        previousLine = ""
        previousLineChars = []
        showPreviousLine = false
        onNewLine = false
        pillHiddenForDrawing = false
        resetIdleTimer()
    }

    func returnToDrawingMode() {
        guard drawingToggleActive else { return }
        pillHiddenForDrawing = true
        let fadeOut = config.config.behavior.fadeOutDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut) { [weak self] in
            guard let self, self.drawingToggleActive else { return }
            self.text = ""
            self.animatedChars = []
            self.nextCharID = 0
            self.textCursorIndex = 0
            self.previousLine = ""
            self.previousLineChars = []
            self.showPreviousLine = false
            self.onNewLine = false
        }
        resetIdleTimer()
    }

    func toggleDrawing() {
        guard drawingAllowed else { return }
        drawingToggleActive.toggle()
        if drawingToggleActive {
            if !isActive {
                // Activate the overlay infrastructure without showing the pill
                text = ""
                animatedChars = []
                nextCharID = 0
                textCursorIndex = 0
                previousLine = ""
                previousLineChars = []
                showPreviousLine = false
                onNewLine = false
                isActive = true
                isVisible = true
                activatedFromDrawingToggle = true
            }
            drawingModeEnabled = true
            pillHiddenForDrawing = true
            resetIdleTimer()
        } else {
            let shouldDismiss = activatedFromDrawingToggle
            activatedFromDrawingToggle = false
            drawingModeEnabled = false
            if shouldDismiss {
                dismiss()
            } else {
                pillHiddenForDrawing = false
            }
        }
    }

    func toggleDictation() {
        dictationModeEnabled.toggle()
        if dictationModeEnabled {
            if !isActive { activate() }
            dictationBaseline = ""
        } else {
            dictationBaseline = ""
        }
    }

    func handleDictationResult(fullText: String, isFinal: Bool) {
        guard isActive else { return }
        if !isVisible { isVisible = true }

        let newText = dictationBaseline + fullText
        let limit = config.config.behavior.charLimit

        // Auto-advance when char limit hit (single-line mode only)
        if !config.config.behavior.multiLine && newText.count >= limit {
            text = String(newText.prefix(limit))
            rebuildAnimatedChars()
            handleNewline()       // moves text to previous line, clears current
            dictationBaseline = ""
            resetIdleTimer()
            return
        }

        text = newText
        rebuildAnimatedChars()

        // On session final: commit full text as baseline for the next session
        if isFinal {
            dictationBaseline = text
        }

        resetIdleTimer()
    }

    func dismiss() {
        idleTimer?.invalidate()
        drawingToggleActive = false
        activatedFromDrawingToggle = false
        if pillHiddenForDrawing { pillHiddenForDrawing = false }
        isActive = false
        isVisible = false
        // Delay content clearing so the fade animation renders with current appearance intact
        let fadeOut = config.config.behavior.fadeOutDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut) { [weak self] in
            guard let self else { return }
            self.text = ""
            self.animatedChars = []
            self.nextCharID = 0
            self.textCursorIndex = 0
            self.previousLine = ""
            self.previousLineChars = []
            self.showPreviousLine = false
            self.onNewLine = false
            self.clearStrokes()
            self.dictationModeEnabled = false
            self.dictationBaseline = ""
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

        let limit = config.config.behavior.charLimit
        let multiLine = config.config.behavior.multiLine

        // In single-line mode, auto-advance to a new line when the limit is hit
        if !multiLine && text.count >= limit {
            handleNewline()
        }

        if multiLine || text.count < limit {
            let atEnd = textCursorIndex >= text.count
            let insertIdx = text.index(text.startIndex, offsetBy: textCursorIndex)
            text.insert(contentsOf: char, at: insertIdx)
            textCursorIndex += char.count

            if atEnd {
                // Normal typing at end — use original animated append
                withAnimation(.spring(duration: 0.25, bounce: 0.1)) {
                    for c in char {
                        animatedChars.append(AnimatedChar(id: nextCharID, character: String(c)))
                        nextCharID += 1
                    }
                }
            } else {
                // Mid-text insert — rebuild chars instantly
                rebuildAnimatedChars()
            }
        }
        resetIdleTimer()
    }

    func handleNewline() {
        guard isActive else { return }
        if !isVisible { isVisible = true }

        if config.config.behavior.multiLine {
            // Insert "\n" at cursor position (same pattern as mid-text char insert)
            let insertIdx = text.index(text.startIndex, offsetBy: textCursorIndex)
            text.insert("\n", at: insertIdx)
            textCursorIndex += 1
            rebuildAnimatedChars()
        } else {
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
                textCursorIndex = 0
            }
        }
        resetIdleTimer()
    }

    func handleBackspace() {
        guard isActive, !text.isEmpty, textCursorIndex > 0 else { return }
        let atEnd = textCursorIndex >= text.count

        let removeIdx = text.index(text.startIndex, offsetBy: textCursorIndex - 1)
        text.remove(at: removeIdx)
        textCursorIndex -= 1

        if atEnd {
            // Deleting from end — use original animated removeLast
            withAnimation(.easeIn(duration: 0.15)) {
                if !animatedChars.isEmpty {
                    animatedChars.removeLast()
                }
            }
        } else {
            // Mid-text delete — rebuild chars instantly
            rebuildAnimatedChars()
        }
        resetIdleTimer()
    }

    func handleArrowLeft() {
        guard isActive, textCursorIndex > 0 else { return }
        textCursorIndex -= 1
        resetIdleTimer()
    }

    func handleArrowRight() {
        guard isActive, textCursorIndex < text.count else { return }
        textCursorIndex += 1
        resetIdleTimer()
    }

    /// Rebuilds animatedChars from text without animation (for mid-text edits)
    private func rebuildAnimatedChars() {
        animatedChars = text.map { c in
            let ac = AnimatedChar(id: nextCharID, character: String(c))
            nextCharID += 1
            return ac
        }
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
