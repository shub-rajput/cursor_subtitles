import Foundation
import AppKit

@MainActor
class SubtitleViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var isActive: Bool = false
    @Published var cursorPosition: NSPoint = .zero
    @Published var isVisible: Bool = false

    var config: ConfigManager { ConfigManager.shared }

    var displayText: String {
        if text.isEmpty { return config.config.style.placeholderText }
        return text
    }

    var isPlaceholder: Bool { text.isEmpty }

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
        isActive = true
        isVisible = true
        resetIdleTimer()
    }

    func dismiss() {
        idleTimer?.invalidate()
        isActive = false
        isVisible = false
        text = ""
    }

    func handleCharacter(_ char: String) {
        guard isActive else { return }
        if !isVisible { isVisible = true }
        if text.count < config.config.behavior.charLimit {
            text += char
        }
        resetIdleTimer()
    }

    func handleNewline() {
        guard isActive else { return }
        if !isVisible { isVisible = true }
        let currentLines = text.components(separatedBy: "\n").count
        if currentLines < config.config.behavior.maxLines {
            text += "\n"
        }
        resetIdleTimer()
    }

    func handleBackspace() {
        guard isActive, !text.isEmpty else { return }
        text.removeLast()
        resetIdleTimer()
    }
}
