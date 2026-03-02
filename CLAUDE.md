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

# Run the app
open CursorSubtitles.app
```

There are no tests or linting configured.

## Architecture

The app runs as a menubar-only accessory (no dock icon). Core data flow:

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
- **OverlayController** — Manages a transparent, click-through NSPanel overlay spanning the screen, hosts SwiftUI via NSHostingView
- **PillView / PillContainerView** — SwiftUI rendering: pill shape, text, blinking cursor, positioned at mouse coordinates with fade animations
- **ConfigManager** — Singleton loading `~/.config/cursor-subtitles/config.json` with DispatchSource file watching for live reload
- **CursorTracker** — Timer-based mouse position polling, updates the view model

## Key Patterns

- All UI classes use `@MainActor` isolation
- Config structs are `Sendable` for thread safety
- AppKit (NSPanel, NSApplication) hosts SwiftUI views via NSHostingView
- Colors are configured as hex strings in JSON, parsed by a custom `Color.fromHex()` extension in PillView
- The overlay window is an NSPanel with `.nonactivatingPanel` style so it never steals focus

## Configuration

User config at `~/.config/cursor-subtitles/config.json` with live reload. Key settings: hotkey, backgroundColor, textColor, fontSize, cornerRadius, idleTimeout, maxWidth, maxLines, charLimit.
