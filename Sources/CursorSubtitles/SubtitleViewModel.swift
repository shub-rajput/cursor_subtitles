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

    func activate() {
        text = ""
        isActive = true
        isVisible = true
    }

    func dismiss() {
        isActive = false
        isVisible = false
        text = ""
    }

    func handleCharacter(_ char: String) {
        guard isActive else { return }
        if text.count < config.config.behavior.charLimit {
            text += char
        }
    }

    func handleNewline() {
        guard isActive else { return }
        let currentLines = text.components(separatedBy: "\n").count
        if currentLines < config.config.behavior.maxLines {
            text += "\n"
        }
    }

    func handleBackspace() {
        guard isActive, !text.isEmpty else { return }
        text.removeLast()
    }
}
