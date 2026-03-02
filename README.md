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
