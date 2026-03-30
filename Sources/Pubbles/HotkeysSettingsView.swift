import SwiftUI

struct HotkeysSettingsView: View {
    @ObservedObject private var configManager = ConfigManager.shared
    @State private var recordingRow: RecordingTarget?

    private enum RecordingTarget {
        case enablePubble
        case drawingMode
        case drawingToggle
    }

    var body: some View {
        Form {
            AccessibilityBannerSection()
            Section {
                // Toggle Pubble mode
                HStack {
                    Text("Toggle Pubble mode")
                    Spacer()

                    if recordingRow == .enablePubble {
                        HotkeyRecorderInline(
                            onRecord: { newHotkey in
                                configManager.setHotkey(newHotkey)
                                recordingRow = nil
                            },
                            onCancel: { recordingRow = nil }
                        )
                    } else {
                        hotkeyKeyCaps(configManager.config.hotkey)
                        recordButton { recordingRow = .enablePubble }
                    }
                }

                // Hold to doodle
                HStack {
                    Text("Hold to doodle")
                    Spacer()

                    if recordingRow == .drawingMode {
                        HotkeyRecorderInline(
                            modifierOnly: true,
                            onRecord: { newHotkey in
                                configManager.setDrawingHotkey(newHotkey)
                                recordingRow = nil
                            },
                            onCancel: { recordingRow = nil }
                        )
                    } else {
                        HStack(spacing: 6) {
                            hotkeyKeyCaps(configManager.config.drawingHotkey)
                            Text("+ Click/Drag")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        recordButton { recordingRow = .drawingMode }
                    }
                }

                hotkeyRow("Change Pubble Scale") {
                    HStack(spacing: 4) {
                        KeyCap("cmd")
                        Text("+")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        KeyCap("\u{2190}/\u{2192}")
                    }
                }

                hotkeyRow("Cycle Themes") {
                    HStack(spacing: 4) {
                        KeyCap("cmd")
                        Text("+")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        KeyCap("\u{2191}/\u{2193}")
                    }
                }

                hotkeyRow("Dismiss Pubble") {
                    KeyCap("Esc")
                }

                hotkeyRow("New Line") {
                    KeyCap("Enter")
                }
            }

            Section {
                // Toggle Doodle mode
                HStack {
                    Text("Toggle Doodle mode")
                    Spacer()

                    if recordingRow == .drawingToggle {
                        HotkeyRecorderInline(
                            onRecord: { newHotkey in
                                configManager.setDrawingToggleHotkey(newHotkey)
                                recordingRow = nil
                            },
                            onCancel: { recordingRow = nil }
                        )
                    } else {
                        hotkeyKeyCaps(configManager.config.drawingToggleHotkey)
                        recordButton { recordingRow = .drawingToggle }
                    }
                }

                hotkeyRow("Show/Hide Pubble while doodling") {
                    hotkeyKeyCaps(configManager.config.hotkey)
                }

                hotkeyRow("Exit Doodle mode") {
                    KeyCap("Esc")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Hotkeys")
    }

    private func recordButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red.opacity(0.8))
                    .frame(width: 6, height: 6)
                Text("Record")
            }
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func hotkeyRow<V: View>(_ label: String, @ViewBuilder shortcut: () -> V) -> some View {
        HStack {
            Text(label)
            Spacer()
            shortcut()
        }
    }

    @ViewBuilder
    private func hotkeyKeyCaps(_ hotkey: String) -> some View {
        let parts = hotkey.lowercased().split(separator: "+").map(String.init)
        let symbols: [String: String] = [
            "cmd": "\u{2318}", "command": "\u{2318}",
            "shift": "\u{21E7}", "ctrl": "\u{2303}", "control": "\u{2303}",
            "alt": "\u{2325}", "option": "\u{2325}", "opt": "\u{2325}",
        ]
        let display = parts.map { symbols[$0] ?? $0 }.joined(separator: " + ")
        KeyCap(display)
    }
}

// MARK: - Key Cap

private struct KeyCap: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

// MARK: - Inline Hotkey Recorder

private struct HotkeyRecorderInline: View {
    let modifierOnly: Bool
    let onRecord: (String) -> Void
    let onCancel: () -> Void

    init(modifierOnly: Bool = false, onRecord: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.modifierOnly = modifierOnly
        self.onRecord = onRecord
        self.onCancel = onCancel
    }

    @State private var eventMonitor: Any?
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                    .opacity(pulse ? 1 : 0.4)

                Text(modifierOnly ? "Press a modifier key..." : "Press shortcut...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(pulse ? 0.7 : 0.3), lineWidth: 1.5)
            )

            Button("Cancel") {
                stopMonitor()
                onCancel()
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .onAppear {
            startRecording()
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onDisappear { stopMonitor() }
    }

    private func startRecording() {
        if modifierOnly {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
                guard !mods.isEmpty else { return event }

                let name: String
                if mods.contains(.command) { name = "cmd" }
                else if mods.contains(.shift) { name = "shift" }
                else if mods.contains(.option) { name = "alt" }
                else { name = "ctrl" }

                stopMonitor()
                onRecord(name)
                return nil
            }
        } else {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])

                if event.keyCode == 53 {
                    stopMonitor()
                    onCancel()
                    return nil
                }

                guard !mods.isEmpty else { return nil }
                guard let keyName = Self.reverseKeyCodeMap[event.keyCode] else { return nil }

                var parts: [String] = []
                if mods.contains(.command) { parts.append("cmd") }
                if mods.contains(.shift) { parts.append("shift") }
                if mods.contains(.option) { parts.append("alt") }
                if mods.contains(.control) { parts.append("ctrl") }
                parts.append(keyName)

                let result = parts.joined(separator: "+")
                stopMonitor()
                onRecord(result)
                return nil
            }
        }
    }

    private func stopMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private static let reverseKeyCodeMap: [UInt16: String] = {
        let map: [String: UInt16] = [
            "/": 44, ".": 47, ",": 43, ";": 41, "'": 39, "[": 33, "]": 30,
            "\\": 42, "-": 27, "=": 24, "`": 50,
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
            "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45,
            "o": 31, "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32,
            "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
            "6": 22, "7": 26, "8": 28, "9": 25,
            "space": 49, "return": 36, "tab": 48,
        ]
        var reversed: [UInt16: String] = [:]
        for (key, code) in map { reversed[code] = key }
        return reversed
    }()
}
