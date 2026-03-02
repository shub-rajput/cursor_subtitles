# Cursor Subtitles - MVP Design

## Overview

A lightweight native macOS menubar app that displays a Figma-style chat bubble overlay near the cursor. Designed for video creators who want real-time on-screen subtitles/annotations while recording, reducing post-production editing. Works well with cursor-tracking screen recorders like Screen.studio.

## Tech Stack

- **Swift + SwiftUI + AppKit hybrid** (Approach 3)
  - AppKit: overlay NSWindow, CGEvent tap for global hotkey + keyboard capture, cursor tracking
  - SwiftUI: pill view rendering, animations (fade in/out, grow/shrink), text layout
- **Config**: JSON file at `~/.config/cursor-subtitles/config.json`
- **Distribution**: single `.app` bundle, open source

## Architecture

```
┌─────────────────────────────────────────┐
│ App (menubar-only, no dock icon)        │
├─────────────────────────────────────────┤
│ EventTapManager                         │
│  - CGEvent tap for global hotkey        │
│  - Keyboard capture when pill is active │
│  - Cursor position tracking             │
├─────────────────────────────────────────┤
│ OverlayWindowController                 │
│  - Transparent, always-on-top NSWindow  │
│  - Click-through when pill not active   │
│  - Hosts SwiftUI pill view              │
├─────────────────────────────────────────┤
│ PillView (SwiftUI)                      │
│  - Rounded pill shape                   │
│  - Live text rendering                  │
│  - Multiline support                    │
│  - Fade in/out animations              │
├─────────────────────────────────────────┤
│ ConfigManager                           │
│  - Reads/watches JSON config file       │
│  - Provides defaults for all values     │
├─────────────────────────────────────────┤
│ MenubarController                       │
│  - Toggle on/off                        │
│  - Edit Config shortcut                 │
│  - Quit                                 │
└─────────────────────────────────────────┘
```

## Pill Behavior

Modeled after Figma's cursor chat:

| State | Visual |
|-------|--------|
| Triggered (empty) | Green pill with "Say something" placeholder, offset bottom-right of cursor |
| Typing | Pill updates live with typed characters. Width grows to fit (up to max). Blinking text cursor. |
| Enter pressed | New line added. Previous text pushed up. Pill grows vertically. Border radius adjusts. |
| Idle 10s | Pill fades out smoothly (~0.5s) |
| Resume typing | Pill fades back in |
| Click anywhere / Escape | Dismiss pill (short fade) |
| New Cmd+/ while visible | Clears text, resets to placeholder |

The pill follows the cursor at all times, maintaining a configurable offset (default: 20px right, 15px below cursor tip).

## Config File

Location: `~/.config/cursor-subtitles/config.json`

```json
{
  "hotkey": "cmd+/",
  "style": {
    "backgroundColor": "#2DA44E",
    "textColor": "#FFFFFF",
    "placeholderText": "Say something",
    "fontSize": 15,
    "fontFamily": "system",
    "cornerRadius": 20,
    "paddingH": 16,
    "paddingV": 8,
    "maxWidth": 300,
    "cursorOffset": { "x": 20, "y": 15 }
  },
  "behavior": {
    "idleTimeout": 10,
    "fadeOutDuration": 0.5,
    "fadeInDuration": 0.2,
    "maxLines": 5,
    "charLimit": 200
  }
}
```

All values have sensible defaults. Missing keys fall back to defaults. Config is watched for live changes (no restart needed).

## Permissions

- **Accessibility** permission required for CGEvent tap (global keyboard capture)
- App will prompt on first launch with clear explanation of why it's needed

## What's NOT in MVP

- No settings UI (config file only)
- No multiple bubble styles/themes
- No name label on the pill
- No custom cursor icon replacement
- No subtitle export/history
- No multi-monitor awareness (follows cursor to whichever screen it's on naturally via NSEvent.mouseLocation)
