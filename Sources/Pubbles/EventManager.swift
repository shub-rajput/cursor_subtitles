@preconcurrency import AppKit
@preconcurrency import CoreGraphics

@MainActor
final class EventManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var selfPtr: Unmanaged<EventManager>?
    private var permissionTimer: Timer?
    private let viewModel: SubtitleViewModel

    init(viewModel: SubtitleViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        if !AXIsProcessTrusted() {
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [promptKey: true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
            waitForPermission()
            return
        }

        setupEventTap()
    }

    private func waitForPermission() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if AXIsProcessTrusted() {
                    self.permissionTimer?.invalidate()
                    self.permissionTimer = nil
                    self.setupEventTap()
                }
            }
        }
    }

    private func setupEventTap() {
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue)

        let retainedSelf = Unmanaged.passRetained(self)
        self.selfPtr = retainedSelf

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<EventManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(type: type, event: event)
            },
            userInfo: retainedSelf.toOpaque()
        )

        guard let tap = eventTap else {
            print("Failed to create event tap.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // Called from the CGEvent tap callback on an arbitrary thread.
    // We only read viewModel.isActive (which is safe enough for a quick check)
    // and dispatch all mutations to the main actor.
    nonisolated private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if it gets disabled by the system, but only if we still have permission
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if AXIsProcessTrusted() {
                if let tap = MainActor.assumeIsolated({ self.eventTap }) {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            } else {
                // Permission was revoked — tear down and wait for re-grant
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self.handlePermissionLost()
                    }
                }
            }
            return Unmanaged.passUnretained(event)
        }

        // Mouse events — drawing or dismiss
        if type == .leftMouseDown || type == .leftMouseDragged || type == .leftMouseUp || type == .rightMouseDown {
            let isActive = MainActor.assumeIsolated { self.viewModel.isActive }
            let drawingEnabled = MainActor.assumeIsolated { self.viewModel.drawingModeEnabled }

            // Right click always dismisses
            if type == .rightMouseDown {
                if isActive {
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { self.viewModel.dismiss() }
                    }
                }
                return Unmanaged.passUnretained(event)
            }

            // Left click: draw if enabled, otherwise dismiss
            if isActive && drawingEnabled {
                let screenPoint: NSPoint = MainActor.assumeIsolated {
                    let mouseLocation = NSEvent.mouseLocation
                    let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
                        ?? NSScreen.main
                    guard let screen = screen else { return NSPoint.zero }
                    let localX = mouseLocation.x - screen.frame.origin.x
                    let localY = screen.frame.height - (mouseLocation.y - screen.frame.origin.y)
                    return NSPoint(x: localX, y: localY)
                }

                if type == .leftMouseDown {
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { self.viewModel.startStroke(at: screenPoint) }
                    }
                    return nil // consume mouseDown to prevent clicks on apps underneath
                } else if type == .leftMouseDragged {
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { self.viewModel.continueStroke(to: screenPoint) }
                    }
                    return Unmanaged.passUnretained(event) // pass through so cursor keeps moving
                } else if type == .leftMouseUp {
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { self.viewModel.endStroke() }
                    }
                    return nil // consume mouseUp
                }
                return Unmanaged.passUnretained(event)
            }

            // Drawing off or pill inactive — left click dismisses
            if type == .leftMouseDown && isActive {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self.viewModel.dismiss() }
                }
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        guard let nsEvent = NSEvent(cgEvent: event) else { return Unmanaged.passUnretained(event) }

        let mods = nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = nsEvent.keyCode
        let characters = nsEvent.characters

        // Configurable hotkey
        let (hotkeyMods, hotkeyCode) = MainActor.assumeIsolated {
            Self.parseHotkey(ConfigManager.shared.config.hotkey)
        }
        if keyCode == hotkeyCode && mods == hotkeyMods {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if self.viewModel.isActive { self.viewModel.dismiss() }
                    else { self.viewModel.activate() }
                }
            }
            return nil
        }

        // Cmd+D toggles drawing mode
        if keyCode == 2 && mods == .command {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.viewModel.drawingModeEnabled.toggle()
                    self.viewModel.showDrawingModeHint(enabled: self.viewModel.drawingModeEnabled)
                }
            }
            return nil
        }

        // Cmd+arrow shortcuts (only when pill is active)
        let cmdArrowActions: [UInt16: @MainActor () -> Void] = [
            125: { ConfigManager.shared.cycleTheme(forward: true) },   // Cmd+Down
            126: { ConfigManager.shared.cycleTheme(forward: false) },  // Cmd+Up
            124: { ConfigManager.shared.adjustPillScale(increase: true) },  // Cmd+Right
            123: { ConfigManager.shared.adjustPillScale(increase: false) }, // Cmd+Left
        ]
        if mods.contains(.command), let action = cmdArrowActions[keyCode] {
            let isActive = MainActor.assumeIsolated { self.viewModel.isActive }
            if isActive {
                DispatchQueue.main.async { MainActor.assumeIsolated { action() } }
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        // When pill not active, pass through
        let isActive = MainActor.assumeIsolated { self.viewModel.isActive }
        guard isActive else { return Unmanaged.passUnretained(event) }

        // Pass through any modifier combos — user's own shortcuts (Raycast, Alfred, app shortcuts, etc.)
        // ⌘+arrows are already handled above before this point, everything else passes through.
        let actionMods: NSEvent.ModifierFlags = [.command, .option, .control]
        if !mods.intersection(actionMods).isEmpty {
            return Unmanaged.passUnretained(event)
        }

        // Escape
        if keyCode == 53 {
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.viewModel.dismiss() }
            }
            return nil
        }
        // Enter
        if keyCode == 36 {
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.viewModel.handleNewline() }
            }
            return nil
        }
        // Backspace
        if keyCode == 51 {
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.viewModel.handleBackspace() }
            }
            return nil
        }
        // Regular characters
        if let chars = characters, !chars.isEmpty {
            let scalar = chars.unicodeScalars.first!
            if !CharacterSet.controlCharacters.contains(scalar) {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self.viewModel.handleCharacter(chars) }
                }
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func handlePermissionLost() {
        viewModel.dismiss()
        tearDownEventTap()
        waitForPermission()
    }

    private func tearDownEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        selfPtr?.release()
        selfPtr = nil
        eventTap = nil
        runLoopSource = nil
    }

    func stop() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        tearDownEventTap()
    }

    // MARK: - Hotkey parsing

    private static let keyCodeMap: [String: UInt16] = [
        "/": 44, ".": 47, ",": 43, ";": 41, "'": 39, "[": 33, "]": 30,
        "\\": 42, "-": 27, "=": 24, "`": 50,
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
        "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45,
        "o": 31, "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32,
        "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
        "6": 22, "7": 26, "8": 28, "9": 25,
        "space": 49, "return": 36, "tab": 48, "escape": 53,
        "delete": 51, "f1": 122, "f2": 120, "f3": 99, "f4": 118,
        "f5": 96, "f6": 97, "f7": 98, "f8": 100, "f9": 101,
        "f10": 109, "f11": 103, "f12": 111,
    ]

    /// Parses a hotkey string like "cmd+/" or "cmd+shift+k" into modifier flags and a key code.
    static func parseHotkey(_ hotkey: String) -> (NSEvent.ModifierFlags, UInt16) {
        let parts = hotkey.lowercased().split(separator: "+").map(String.init)
        var mods: NSEvent.ModifierFlags = []
        var code: UInt16 = 44 // default: /

        for part in parts {
            switch part {
            case "cmd", "command": mods.insert(.command)
            case "shift": mods.insert(.shift)
            case "alt", "option", "opt": mods.insert(.option)
            case "ctrl", "control": mods.insert(.control)
            default:
                if let mapped = keyCodeMap[part] {
                    code = mapped
                }
            }
        }

        // Default to cmd if no modifiers specified
        if mods.isEmpty { mods = .command }

        return (mods, code)
    }
}
