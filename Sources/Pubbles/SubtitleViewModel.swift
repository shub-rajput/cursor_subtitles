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
                self?.isVisible = false
            }
        }
    }

    func activate() {
        text = ""
        previousLine = ""
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
        text = ""
        previousLine = ""
        showPreviousLine = false
        onNewLine = false
    }

    func showOnboarding() {
        // Ensure activeScreenID is set so the pill renders on the correct screen
        if activeScreenID == nil,
           let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main {
            activeScreenID = ObjectIdentifier(screen)
        }
        previousLine = "Hey! Press ⌘/ to enable Pubbles"
        showPreviousLine = true
        text = "Check the menubar for more settings!"
        onNewLine = false
        isActive = true
        isVisible = true
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.dismiss() }
        }
    }

    func handleCharacter(_ char: String) {
        guard isActive else { return }
        if !isVisible { isVisible = true }

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
}
