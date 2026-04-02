# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Pubbles is a native macOS menubar app that displays chat bubbles near the pointer for real-time on-screen subtitles while screen recording. It has no external dependencies — pure Swift with AppKit, SwiftUI, and CoreGraphics.

**Platform:** macOS 14.0+ (Sonoma) | **Swift Tools:** 6.0 | **Build System:** Swift Package Manager

## Build & Run

```bash
# Development build
swift build

# Release build + app bundle (compiles, bundles, codesigns)
./scripts/build.sh

# Update (quit, pull, rebuild, relaunch)
./scripts/update.sh

# Run the app
open Pubbles.app
```

There are no tests or linting configured.

## Architecture

The app runs as a menubar-only accessory (`LSUIElement = true`, no dock icon). Entry point is `main.swift` which manually creates `NSApplication`, sets `.accessory` activation policy, and calls `app.run()` — no `@main` attribute.

Core data flow:

```
EventManager (CGEvent tap: hotkey Cmd+/, Cmd+B, Cmd+D, keyboard input, mouse draw events)
    ↓
SubtitleViewModel (text state, drawing strokes, dictation state, idle timeout, visibility)
    ↓                                    ↑
PillContainerView → PillView + DrawingCanvasView    SpeechManager (SFSpeechRecognizer + AVAudioEngine)
    ↑
CursorTracker (60 FPS mouse position via timer)
```

**Key components:**

- **AppDelegate** — Orchestrates all components: menubar setup, creates EventManager/CursorTracker/OverlayController/SpeechManager, wires them to the shared SubtitleViewModel. Observes `dictationModeEnabled` via Combine to start/stop SpeechManager with permission handling
- **EventManager** — CGEvent tap for global hotkey capture, keyboard input routing, and mouse event capture for drawing mode. Requires Accessibility permission
- **SpeechManager** — Streaming speech recognition via SFSpeechRecognizer + AVAudioEngine. Intentionally non-`@MainActor` to avoid audio-thread isolation crashes. Restarts sessions on silence/final results. Static helpers for permission checks and prompts
- **SubtitleViewModel** — Central state: current text, previous line, visibility, idle timer, drawing strokes, dictation mode. ObservableObject driving SwiftUI. Dictation state tracks a baseline + session offset so keyboard edits and speech don't overwrite each other
- **OverlayController** — Manages the overlay window lifecycle, hosts SwiftUI via NSHostingView
- **OverlayWindow** — Transparent, click-through NSPanel (`.nonactivatingPanel`, `ignoresMouseEvents = true`) spanning the full screen
- **PillView / PillContainerView** — SwiftUI rendering: pill shape, text, blinking cursor, positioned at mouse coordinates with fade animations. PillContainerView also hosts `DrawingCanvasView` (SwiftUI Canvas for stroke rendering)
- **ConfigManager** — Singleton managing config with deep-merge resolution (defaults → theme → user overrides), DispatchSource file watching for live reload, theme file seeding from bundle, and menubar helpers (`setTheme`, `setColor`, `availableThemes`)
- **CursorTracker** — Timer-based mouse position polling, updates the view model
- **PermissionMonitor** — Generic `ObservableObject` that polls a permission check on a 1s timer, self-invalidates once granted. Shared instances for Accessibility and Microphone/Speech
- **SettingsWindowController** — NSWindowController hosting `SettingsView` (SwiftUI). Switches activation policy to `.regular` on open and back to `.accessory` on close so the settings window can receive focus without making the app appear in the Dock permanently
- **UpdateChecker** — Singleton that checks GitHub releases API for newer versions, prompts the user, and self-updates by downloading and running the install script via a detached `launchctl` job before quitting. Skipped versions are persisted in `UserDefaults`

## Key Patterns

- All UI classes use `@MainActor` isolation
- Config structs (`AppConfig`, `StyleConfig`, `BehaviorConfig`) are `Codable` and `Sendable` — defaults are defined as struct property defaults, not separate constants
- AppKit (NSPanel, NSApplication) hosts SwiftUI views via NSHostingView
- Colors are configured as hex strings in JSON, parsed by a `Color.fromHex()` extension in PillView
- The overlay is an NSPanel that never steals focus and ignores all mouse events
- The build script (`scripts/build.sh`) copies the binary, Info.plist, and Resources/ into a `.app` bundle, then codesigns if a local "Pubbles" certificate exists
- Drawing mode is a global toggle (Cmd+D / menu item) that changes left-click behavior while the pill is active: clicks become strokes instead of dismissing. `currentStroke` is not `@Published` — a `TimelineView` polls it at display refresh rate to avoid triggering PillView redraws. On dismiss, content clearing is delayed until after the fade animation completes

## Themes

Ghostty-style file-based themes in `~/.config/pubbles/themes/`. Built-in themes shipped in `Resources/themes/`, seeded to user dir on first launch. Theme files are JSON with a `name` field plus any `style`/`behavior` keys.

Config merge order: **defaults → theme → user config** (user always wins). Merge uses `JSONSerialization` deep-merge, not `Codable`, to distinguish absent keys from default values.

When `setTheme()` is called, it clears user `style` and `behavior` overrides from config.json so the theme takes full effect.

PillView supports three background modes via StyleConfig fields: `vibrancy` (SwiftUI Material), `backgroundGradient` (LinearGradient), `glassEffect` (Apple Liquid Glass on macOS 26+), or solid `backgroundColor`.

## Configuration

User config at `~/.config/pubbles/config.json` with live reload via file watcher. The JSON structure mirrors the Swift structs:

```
AppConfig
├── hotkey: String
├── dictationHotkey: String (default: cmd+b)
├── drawingHotkey: String (modifier for hold-to-draw)
├── drawingToggleHotkey: String (default: cmd+d)
├── theme: String? (matches filename in themes dir)
├── style: StyleConfig (backgroundColor, backgroundOpacity, vibrancy, backgroundGradient, glassEffect, textColor, fontSize, cornerRadius, maxWidth, cursorOffset, border*, shadow*, drawingLineColor, drawingLineWidth, ...)
└── behavior: BehaviorConfig (idleTimeout, fadeOutDuration, fadeInDuration, maxLines, charLimit)
```

When adding new config options: add the field with a default value to the appropriate struct in `Config.swift`. The `Codable` conformance handles missing keys gracefully (uses defaults).
