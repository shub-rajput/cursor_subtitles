# Cursor Subtitles Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native macOS menubar app that displays a Figma-style cursor chat bubble overlay, usable for real-time video subtitles while screen recording.

**Architecture:** SwiftUI + AppKit hybrid. AppKit manages the overlay NSPanel, CGEvent tap for global hotkey/keyboard capture, and cursor tracking. SwiftUI renders the pill view with animations. Config via JSON file. No Xcode project — uses Swift Package Manager with a shell script to create the .app bundle.

**Tech Stack:** Swift 5.9+, macOS 13+, AppKit, SwiftUI, CoreGraphics (CGEvent), Swift Package Manager

---

### Task 1: Project Scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/CursorSubtitles/main.swift`
- Create: `Info.plist`
- Create: `scripts/build.sh`
- Create: `.gitignore`

**Step 1: Initialize git repo**

Run: `cd "/Users/shub/Documents/Cursor Projects/cursor_subtitles" && git init`

**Step 2: Create .gitignore**

```
.build/
*.app
.DS_Store
.swiftpm/
```

**Step 3: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CursorSubtitles",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CursorSubtitles",
            path: "Sources/CursorSubtitles"
        )
    ]
)
```

**Step 4: Create minimal main.swift**

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No dock icon
app.run()
```

**Step 5: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.cursor-subtitles.app</string>
    <key>CFBundleExecutable</key>
    <string>CursorSubtitles</string>
    <key>CFBundleName</key>
    <string>Cursor Subtitles</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>Cursor Subtitles needs accessibility access to capture global hotkeys and keyboard input.</string>
</dict>
</plist>
```

**Step 6: Create build script**

Create `scripts/build.sh`:

```bash
#!/bin/bash
set -e

APP_NAME="CursorSubtitles"
BUILD_DIR=".build/release"

swift build -c release

rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_NAME}.app/Contents/MacOS/"
cp "Info.plist" "${APP_NAME}.app/Contents/"

codesign --force --deep --sign - "${APP_NAME}.app"

echo "Built ${APP_NAME}.app"
echo "Run with: open ${APP_NAME}.app"
```

Run: `chmod +x scripts/build.sh`

**Step 7: Verify it compiles**

Run: `swift build`
Expected: Build succeeds with no errors.

**Step 8: Commit**

```bash
git add Package.swift Sources/ Info.plist scripts/ .gitignore
git commit -m "feat: project scaffold with SPM, Info.plist, and build script"
```

---

### Task 2: Menubar App with AppDelegate

**Files:**
- Create: `Sources/CursorSubtitles/AppDelegate.swift`
- Modify: `Sources/CursorSubtitles/main.swift`

**Step 1: Create AppDelegate**

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenubar()
    }

    private func setupMenubar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bubble.left.fill", accessibilityDescription: "Cursor Subtitles")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Subtitles", action: #selector(toggleSubtitles), keyEquivalent: "/"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func toggleSubtitles() {
        // Will be implemented in later tasks
        print("Toggle subtitles")
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
```

**Step 2: Update main.swift to use AppDelegate**

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

**Step 3: Build and test**

Run: `swift build`
Expected: Compiles successfully.

Run: `scripts/build.sh && open CursorSubtitles.app`
Expected: Menubar icon appears (speech bubble). Clicking shows menu with "Toggle Subtitles" and "Quit". Quit exits the app.

**Step 4: Commit**

```bash
git add Sources/
git commit -m "feat: menubar app with status item and basic menu"
```

---

### Task 3: Config Manager

**Files:**
- Create: `Sources/CursorSubtitles/Config.swift`

**Step 1: Create Config with Codable structs and defaults**

```swift
import Foundation

struct CursorOffset: Codable {
    var x: CGFloat = 20
    var y: CGFloat = 15
}

struct StyleConfig: Codable {
    var backgroundColor: String = "#2DA44E"
    var textColor: String = "#FFFFFF"
    var placeholderText: String = "Say something"
    var fontSize: CGFloat = 15
    var fontFamily: String = "system"
    var cornerRadius: CGFloat = 20
    var paddingH: CGFloat = 16
    var paddingV: CGFloat = 8
    var maxWidth: CGFloat = 300
    var cursorOffset: CursorOffset = CursorOffset()
}

struct BehaviorConfig: Codable {
    var idleTimeout: Double = 10
    var fadeOutDuration: Double = 0.5
    var fadeInDuration: Double = 0.2
    var maxLines: Int = 5
    var charLimit: Int = 200
}

struct AppConfig: Codable {
    var hotkey: String = "cmd+/"
    var style: StyleConfig = StyleConfig()
    var behavior: BehaviorConfig = BehaviorConfig()
}

class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    @Published var config: AppConfig = AppConfig()

    private let configURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/cursor-subtitles")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()

    private var fileMonitor: DispatchSourceFileSystemObject?

    init() {
        loadConfig()
        watchConfig()
    }

    func loadConfig() {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            saveDefaultConfig()
            return
        }
        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            config = try decoder.decode(AppConfig.self, from: data)
        } catch {
            print("Failed to load config: \(error). Using defaults.")
            config = AppConfig()
        }
    }

    private func saveDefaultConfig() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL)
        } catch {
            print("Failed to save default config: \(error)")
        }
    }

    private func watchConfig() {
        let fd = open(configURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        fileMonitor?.setEventHandler { [weak self] in
            self?.loadConfig()
        }
        fileMonitor?.setCancelHandler {
            close(fd)
        }
        fileMonitor?.resume()
    }
}
```

**Step 2: Verify it compiles**

Run: `swift build`
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add Sources/CursorSubtitles/Config.swift
git commit -m "feat: config manager with JSON file, defaults, and live reload"
```

---

### Task 4: Overlay Window

**Files:**
- Create: `Sources/CursorSubtitles/OverlayWindow.swift`
- Create: `Sources/CursorSubtitles/OverlayController.swift`

**Step 1: Create OverlayWindow (NSPanel subclass)**

```swift
import AppKit

class OverlayWindow: NSPanel {
    init() {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

**Step 2: Create OverlayController**

```swift
import AppKit
import SwiftUI

class OverlayController {
    private var window: OverlayWindow?
    private let viewModel: SubtitleViewModel

    init(viewModel: SubtitleViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        if window == nil {
            window = OverlayWindow()
            let hostingView = NSHostingView(rootView: PillContainerView(viewModel: viewModel))
            hostingView.frame = window!.contentRect(forFrameRect: window!.frame)
            hostingView.autoresizingMask = [.width, .height]
            window!.contentView = hostingView
        }
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }
}
```

**Step 3: Create placeholder SubtitleViewModel and PillContainerView**

Create `Sources/CursorSubtitles/SubtitleViewModel.swift`:

```swift
import Foundation
import AppKit

class SubtitleViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var isActive: Bool = false
    @Published var cursorPosition: NSPoint = .zero
    @Published var isVisible: Bool = false

    var config: ConfigManager { ConfigManager.shared }

    var displayText: String {
        if text.isEmpty {
            return config.config.style.placeholderText
        }
        return text
    }

    var isPlaceholder: Bool {
        text.isEmpty
    }

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
        let limit = config.config.behavior.charLimit
        if text.count < limit {
            text += char
        }
    }

    func handleNewline() {
        guard isActive else { return }
        let maxLines = config.config.behavior.maxLines
        let currentLines = text.components(separatedBy: "\n").count
        if currentLines < maxLines {
            text += "\n"
        }
    }

    func handleBackspace() {
        guard isActive, !text.isEmpty else { return }
        text.removeLast()
    }
}
```

Create `Sources/CursorSubtitles/PillContainerView.swift`:

```swift
import SwiftUI

struct PillContainerView: View {
    @ObservedObject var viewModel: SubtitleViewModel

    var body: some View {
        ZStack {
            Color.clear // Full-screen transparent background

            if viewModel.isVisible {
                PillView(viewModel: viewModel)
                    .position(
                        x: viewModel.cursorPosition.x + ConfigManager.shared.config.style.cursorOffset.x + 60,
                        y: viewModel.cursorPosition.y + ConfigManager.shared.config.style.cursorOffset.y
                    )
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isVisible)
    }
}
```

Create `Sources/CursorSubtitles/PillView.swift`:

```swift
import SwiftUI

struct PillView: View {
    @ObservedObject var viewModel: SubtitleViewModel

    private var style: StyleConfig { ConfigManager.shared.config.style }

    private var bgColor: Color {
        Color(hex: style.backgroundColor) ?? .green
    }

    private var txtColor: Color {
        Color(hex: style.textColor) ?? .white
    }

    var body: some View {
        Text(viewModel.displayText)
            .font(.system(size: style.fontSize, weight: .medium))
            .foregroundColor(viewModel.isPlaceholder ? txtColor.opacity(0.7) : txtColor)
            .padding(.horizontal, style.paddingH)
            .padding(.vertical, style.paddingV)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
            .fixedSize()
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6,
              let hexNumber = UInt64(hexSanitized, radix: 16) else {
            return nil
        }

        let r = Double((hexNumber & 0xFF0000) >> 16) / 255
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255
        let b = Double(hexNumber & 0x0000FF) / 255

        self.init(red: r, green: g, blue: b)
    }
}
```

**Step 4: Verify it compiles**

Run: `swift build`
Expected: Build succeeds.

**Step 5: Commit**

```bash
git add Sources/
git commit -m "feat: overlay window, pill view, and subtitle view model"
```

---

### Task 5: Event Handling — Hotkey and Keyboard Capture

**Files:**
- Create: `Sources/CursorSubtitles/EventManager.swift`
- Modify: `Sources/CursorSubtitles/AppDelegate.swift`

**Step 1: Create EventManager with CGEvent tap**

```swift
import AppKit
import CoreGraphics

class EventManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let viewModel: SubtitleViewModel

    init(viewModel: SubtitleViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            print("Accessibility permission not granted. Please enable in System Settings > Privacy & Security > Accessibility.")
            return
        }

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
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<EventManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        )

        guard let tap = eventTap else {
            print("Failed to create event tap. Check accessibility permissions.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Mouse click dismisses the pill
        if type == .leftMouseDown || type == .rightMouseDown {
            if viewModel.isActive {
                DispatchQueue.main.async {
                    self.viewModel.dismiss()
                }
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }

        let mods = nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd+/ hotkey (keyCode 44 = `/`)
        if nsEvent.keyCode == 44 && mods.contains(.command) {
            DispatchQueue.main.async {
                if self.viewModel.isActive {
                    self.viewModel.dismiss()
                } else {
                    self.viewModel.activate()
                }
            }
            return nil // Consume the event
        }

        // When pill is active, capture keyboard input
        guard viewModel.isActive else {
            return Unmanaged.passUnretained(event)
        }

        // Escape dismisses
        if nsEvent.keyCode == 53 {
            DispatchQueue.main.async {
                self.viewModel.dismiss()
            }
            return nil
        }

        // Return/Enter adds new line
        if nsEvent.keyCode == 36 {
            DispatchQueue.main.async {
                self.viewModel.handleNewline()
            }
            return nil
        }

        // Backspace
        if nsEvent.keyCode == 51 {
            DispatchQueue.main.async {
                self.viewModel.handleBackspace()
            }
            return nil
        }

        // Regular character input
        if let chars = nsEvent.characters, !chars.isEmpty {
            // Ignore control characters (except those already handled)
            let scalar = chars.unicodeScalars.first!
            if !CharacterSet.controlCharacters.contains(scalar) {
                DispatchQueue.main.async {
                    self.viewModel.handleCharacter(chars)
                }
                return nil // Consume so it doesn't type in the active app
            }
        }

        return Unmanaged.passUnretained(event)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
}
```

**Step 2: Create CursorTracker**

Create `Sources/CursorSubtitles/CursorTracker.swift`:

```swift
import AppKit

class CursorTracker {
    private var monitor: Any?
    private var timer: Timer?
    private let viewModel: SubtitleViewModel

    init(viewModel: SubtitleViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        // Use a timer for smooth tracking since global mouse monitors
        // don't fire during event tap keyboard capture
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let mouseLocation = NSEvent.mouseLocation
            // Convert from Cocoa coords (bottom-left origin) to screen coords for the overlay
            if let screen = NSScreen.main {
                let flippedY = screen.frame.height - mouseLocation.y
                self.viewModel.cursorPosition = NSPoint(x: mouseLocation.x, y: flippedY)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
```

**Step 3: Update AppDelegate to wire everything together**

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let viewModel = SubtitleViewModel()
    private var overlayController: OverlayController!
    private var eventManager: EventManager!
    private var cursorTracker: CursorTracker!
    private var isEnabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlayController = OverlayController(viewModel: viewModel)
        eventManager = EventManager(viewModel: viewModel)
        cursorTracker = CursorTracker(viewModel: viewModel)

        setupMenubar()
        overlayController.show()
        eventManager.start()
        cursorTracker.start()
    }

    private func setupMenubar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bubble.left.fill", accessibilityDescription: "Cursor Subtitles")
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.state = .on
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Edit Config...", action: #selector(openConfig), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        if isEnabled {
            eventManager.start()
            overlayController.show()
            statusItem.menu?.item(at: 0)?.state = .on
        } else {
            viewModel.dismiss()
            eventManager.stop()
            overlayController.hide()
            statusItem.menu?.item(at: 0)?.state = .off
        }
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config/cursor-subtitles/config.json")
        )
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
```

**Step 4: Verify it compiles**

Run: `swift build`
Expected: Build succeeds.

**Step 5: Build app bundle and test**

Run: `scripts/build.sh && open CursorSubtitles.app`
Expected: App launches. Menubar icon appears. Pressing Cmd+/ shows the green pill with "Say something" near the cursor. Typing updates the pill text. Escape or clicking dismisses it. Pill follows the cursor.

**Step 6: Commit**

```bash
git add Sources/
git commit -m "feat: event handling, cursor tracking, and full app wiring"
```

---

### Task 6: Idle Timeout and Fade Animations

**Files:**
- Modify: `Sources/CursorSubtitles/SubtitleViewModel.swift`
- Modify: `Sources/CursorSubtitles/PillContainerView.swift`

**Step 1: Add idle timer to SubtitleViewModel**

Add to `SubtitleViewModel`:

```swift
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
```

Update `handleCharacter`, `handleNewline`, and `handleBackspace` to call `resetIdleTimer()` after modifying text. Update `activate()` to call `resetIdleTimer()`. Update `dismiss()` to invalidate the timer.

**Step 2: Update PillContainerView fade animation durations to use config**

```swift
struct PillContainerView: View {
    @ObservedObject var viewModel: SubtitleViewModel

    private var fadeIn: Double { ConfigManager.shared.config.behavior.fadeInDuration }
    private var fadeOut: Double { ConfigManager.shared.config.behavior.fadeOutDuration }

    var body: some View {
        ZStack {
            Color.clear

            if viewModel.isVisible {
                PillView(viewModel: viewModel)
                    .position(
                        x: viewModel.cursorPosition.x + ConfigManager.shared.config.style.cursorOffset.x + 60,
                        y: viewModel.cursorPosition.y + ConfigManager.shared.config.style.cursorOffset.y
                    )
                    .transition(.opacity.animation(.easeInOut(duration: fadeOut)))
            }
        }
        .animation(viewModel.isVisible
            ? .easeInOut(duration: fadeIn)
            : .easeInOut(duration: fadeOut),
            value: viewModel.isVisible
        )
    }
}
```

**Step 3: Also fade back in when user resumes typing after idle fade**

In `SubtitleViewModel.handleCharacter`, before adding the character, check if `!isVisible` and if so, set `isVisible = true` (the fade-in animation handles the rest). Same for `handleNewline`.

**Step 4: Build and test**

Run: `scripts/build.sh && open CursorSubtitles.app`
Expected: Trigger pill, type something, wait 10 seconds — pill fades out. Start typing again — pill fades back in. Escape/click still dismisses immediately.

**Step 5: Commit**

```bash
git add Sources/
git commit -m "feat: idle timeout with fade in/out animations"
```

---

### Task 7: Polish — Blinking Cursor and Multi-line Pill Shape

**Files:**
- Modify: `Sources/CursorSubtitles/PillView.swift`

**Step 1: Add blinking text cursor**

Update `PillView` to show a blinking cursor indicator when active:

```swift
struct PillView: View {
    @ObservedObject var viewModel: SubtitleViewModel
    @State private var cursorVisible = true

    private var style: StyleConfig { ConfigManager.shared.config.style }

    private var bgColor: Color {
        Color(hex: style.backgroundColor) ?? .green
    }

    private var txtColor: Color {
        Color(hex: style.textColor) ?? .white
    }

    private var dynamicCornerRadius: CGFloat {
        let lineCount = viewModel.displayText.components(separatedBy: "\n").count
        if lineCount > 1 {
            return min(style.cornerRadius, 16)
        }
        return style.cornerRadius
    }

    var body: some View {
        HStack(spacing: 0) {
            if viewModel.isPlaceholder {
                Text(viewModel.displayText)
                    .font(.system(size: style.fontSize, weight: .medium))
                    .foregroundColor(txtColor.opacity(0.7))
            } else {
                Text(viewModel.displayText)
                    .font(.system(size: style.fontSize, weight: .medium))
                    .foregroundColor(txtColor)
                + Text(cursorVisible && viewModel.isActive ? "|" : " ")
                    .font(.system(size: style.fontSize, weight: .light))
                    .foregroundColor(txtColor)
            }
        }
        .padding(.horizontal, style.paddingH)
        .padding(.vertical, style.paddingV)
        .frame(maxWidth: style.maxWidth, alignment: .leading)
        .fixedSize()
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: dynamicCornerRadius, style: .continuous))
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.53, repeats: true) { _ in
                cursorVisible.toggle()
            }
        }
    }
}
```

**Step 2: Build and test**

Run: `scripts/build.sh && open CursorSubtitles.app`
Expected: Pill shows blinking cursor while typing. Multi-line text shows with reduced corner radius. Pill grows vertically with new lines.

**Step 3: Commit**

```bash
git add Sources/
git commit -m "feat: blinking cursor indicator and multi-line pill shape"
```

---

### Task 8: Final Integration Test and README

**Files:**
- Create: `README.md`

**Step 1: Full end-to-end test**

Run: `scripts/build.sh && open CursorSubtitles.app`

Test checklist:
- [ ] Menubar icon appears
- [ ] Cmd+/ shows pill with "Say something" placeholder
- [ ] Typing replaces placeholder with actual text
- [ ] Pill follows cursor
- [ ] Enter creates new line, text pushes up
- [ ] Escape dismisses pill
- [ ] Clicking anywhere dismisses pill
- [ ] Idle 10s causes fade out
- [ ] Typing after fade brings it back
- [ ] Cmd+/ while pill visible clears and resets
- [ ] "Edit Config..." opens config JSON
- [ ] Editing config values (e.g., backgroundColor) applies live
- [ ] "Enabled" toggle works
- [ ] "Quit" exits the app

**Step 2: Create README.md**

```markdown
# Cursor Subtitles

A lightweight macOS menubar app that displays Figma-style cursor chat bubbles — perfect for real-time subtitles while screen recording.

## Install

```bash
git clone <repo>
cd cursor-subtitles
chmod +x scripts/build.sh
scripts/build.sh
open CursorSubtitles.app
```

## Usage

1. Press **Cmd+/** to activate the subtitle bubble
2. Type your text — it appears in a pill near your cursor
3. Press **Enter** for a new line
4. Press **Escape** or click anywhere to dismiss
5. The pill follows your cursor and fades after 10s of inactivity

## Configuration

Edit `~/.config/cursor-subtitles/config.json` to customize:

- `hotkey` — trigger shortcut (default: `cmd+/`)
- `style.backgroundColor` — pill color (hex, default: `#2DA44E`)
- `style.textColor` — text color (hex, default: `#FFFFFF`)
- `style.placeholderText` — placeholder (default: `Say something`)
- `style.fontSize` — font size (default: `15`)
- `style.cornerRadius` — pill roundness (default: `20`)
- `style.maxWidth` — max pill width (default: `300`)
- `behavior.idleTimeout` — seconds before fade (default: `10`)
- `behavior.maxLines` — max line count (default: `5`)

Changes apply instantly — no restart needed.

## Permissions

Requires **Accessibility** permission for global hotkey capture. The app will prompt on first launch.

## License

MIT
```

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README with install, usage, and config instructions"
```

---

## Summary

| Task | Description | Estimated Time |
|------|-------------|---------------|
| 1 | Project scaffold (SPM, Info.plist, build script) | 10 min |
| 2 | Menubar app with AppDelegate | 10 min |
| 3 | Config manager with JSON + live reload | 15 min |
| 4 | Overlay window + pill view + view model | 20 min |
| 5 | Event handling (hotkey, keyboard capture, cursor tracking) | 25 min |
| 6 | Idle timeout and fade animations | 15 min |
| 7 | Blinking cursor and multi-line polish | 10 min |
| 8 | Integration test and README | 10 min |
| **Total** | | **~2 hours** |
