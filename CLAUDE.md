# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

CursorSubtitles is a native macOS menubar app that displays Figma-style chat bubbles near the cursor for real-time on-screen subtitles while screen recording. It has no external dependencies — pure Swift with AppKit, SwiftUI, and CoreGraphics.

**Platform:** macOS 13.0+ | **Swift Tools:** 6.0 | **Build System:** Swift Package Manager

## Build & Run

```bash
# Development build
swift build

# Release build + app bundle (compiles, bundles, codesigns)
./scripts/build.sh

# Update (quit, pull, rebuild, relaunch)
./scripts/update.sh

# Run the app
open CursorSubtitles.app
```

There are no tests or linting configured.

## Architecture

The app runs as a menubar-only accessory (`LSUIElement = true`, no dock icon). Entry point is `main.swift` which manually creates `NSApplication`, sets `.accessory` activation policy, and calls `app.run()` — no `@main` attribute.

Core data flow:

```
EventManager (CGEvent tap: hotkey Cmd+/, keyboard input)
    ↓
SubtitleViewModel (text state, idle timeout, visibility)
    ↓
PillContainerView → PillView (SwiftUI pill at cursor position)
    ↑
CursorTracker (60 FPS mouse position via timer)
```

**Key components:**

- **AppDelegate** — Orchestrates all components: menubar setup, creates EventManager/CursorTracker/OverlayController, wires them to the shared SubtitleViewModel
- **EventManager** — CGEvent tap for global hotkey capture and keyboard input routing. Requires Accessibility permission
- **SubtitleViewModel** — Central state: current text, previous line, visibility, idle timer. ObservableObject driving SwiftUI
- **OverlayController** — Manages the overlay window lifecycle, hosts SwiftUI via NSHostingView
- **OverlayWindow** — Transparent, click-through NSPanel (`.nonactivatingPanel`, `ignoresMouseEvents = true`) spanning the full screen
- **PillView / PillContainerView** — SwiftUI rendering: pill shape, text, blinking cursor, positioned at mouse coordinates with fade animations
- **ConfigManager** — Singleton managing config with deep-merge resolution (defaults → theme → user overrides), DispatchSource file watching for live reload, theme file seeding from bundle, and menubar helpers (`setTheme`, `setColor`, `availableThemes`)
- **CursorTracker** — Timer-based mouse position polling, updates the view model

## Key Patterns

- All UI classes use `@MainActor` isolation
- Config structs (`AppConfig`, `StyleConfig`, `BehaviorConfig`) are `Codable` and `Sendable` — defaults are defined as struct property defaults, not separate constants
- AppKit (NSPanel, NSApplication) hosts SwiftUI views via NSHostingView
- Colors are configured as hex strings in JSON, parsed by a `Color.fromHex()` extension in PillView
- The overlay is an NSPanel that never steals focus and ignores all mouse events
- The build script (`scripts/build.sh`) copies the binary, Info.plist, and Resources/ into a `.app` bundle, then codesigns if a local "CursorSubtitles" certificate exists

## Themes

Ghostty-style file-based themes in `~/.config/cursor-subtitles/themes/`. Built-in themes shipped in `Resources/themes/`, seeded to user dir on first launch. Theme files are JSON with a `name` field plus any `style`/`behavior` keys.

Config merge order: **defaults → theme → user config** (user always wins). Merge uses `JSONSerialization` deep-merge, not `Codable`, to distinguish absent keys from default values.

When `setTheme()` is called, it clears user `style` and `behavior` overrides from config.json so the theme takes full effect.

PillView supports three background modes via StyleConfig fields: `vibrancy` (SwiftUI Material), `backgroundGradient` (LinearGradient), `glassEffect` (Apple Liquid Glass on macOS 26+), or solid `backgroundColor`.

## Configuration

User config at `~/.config/cursor-subtitles/config.json` with live reload via file watcher. The JSON structure mirrors the Swift structs:

```
AppConfig
├── hotkey: String
├── theme: String? (matches filename in themes dir)
├── style: StyleConfig (backgroundColor, backgroundOpacity, vibrancy, backgroundGradient, glassEffect, textColor, fontSize, cornerRadius, maxWidth, cursorOffset, border*, shadow*, ...)
└── behavior: BehaviorConfig (idleTimeout, fadeOutDuration, fadeInDuration, maxLines, charLimit)
```

When adding new config options: add the field with a default value to the appropriate struct in `Config.swift`. The `Codable` conformance handles missing keys gracefully (uses defaults).
