@preconcurrency import AppKit
@preconcurrency import CoreGraphics

@MainActor
final class EventManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
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
            (1 << CGEventType.rightMouseDown.rawValue)

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

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
            userInfo: selfPtr
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

        // Mouse click dismisses pill
        if type == .leftMouseDown || type == .rightMouseDown {
            let isActive = MainActor.assumeIsolated { self.viewModel.isActive }
            if isActive {
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

        // Cmd+/ hotkey (keyCode 44)
        if keyCode == 44 && mods.contains(.command) {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if self.viewModel.isActive { self.viewModel.dismiss() }
                    else { self.viewModel.activate() }
                }
            }
            return nil
        }

        // Cmd+Down: next theme (keyCode 125)
        if keyCode == 125 && mods.contains(.command) {
            let isActive = MainActor.assumeIsolated { self.viewModel.isActive }
            if isActive {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        ConfigManager.shared.cycleTheme(forward: true)
                    }
                }
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        // Cmd+Up: previous theme (keyCode 126)
        if keyCode == 126 && mods.contains(.command) {
            let isActive = MainActor.assumeIsolated { self.viewModel.isActive }
            if isActive {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        ConfigManager.shared.cycleTheme(forward: false)
                    }
                }
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        // When pill not active, pass through
        let isActive = MainActor.assumeIsolated { self.viewModel.isActive }
        guard isActive else { return Unmanaged.passUnretained(event) }

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
        eventTap = nil
        runLoopSource = nil
    }

    func stop() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        tearDownEventTap()
    }
}
