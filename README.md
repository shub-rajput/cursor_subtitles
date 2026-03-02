# Cursor Subtitles

A lightweight macOS menubar app that displays Figma-style cursor chat bubbles — perfect for real-time subtitles while screen recording.

## Install

```bash
git clone <repo>
cd cursor-subtitles
chmod +x scripts/build.sh
./scripts/build.sh
open CursorSubtitles.app
```

## Usage

1. Press **Cmd+/** to activate the subtitle bubble
2. Type your text — it appears in a pill near your cursor
3. Press **Enter** for a new line
4. Press **Escape** or click anywhere to dismiss
5. The pill follows your cursor and fades after 10s of inactivity

## Updating

```bash
./scripts/update.sh
```

This quits the app, pulls latest changes, rebuilds, and reopens. If you don't have a signing certificate, it will also reset permissions and prompt you to re-grant Accessibility access.

To avoid the permission prompt on every update, set up a signing certificate (see below).

## Signing Certificate (Recommended)

Without a local signing certificate, macOS invalidates Accessibility permission every time you rebuild. To avoid this:

1. Open **Keychain Access** (Spotlight → "Keychain Access")
2. Menu: **Keychain Access → Certificate Assistant → Create a Certificate...**
3. Set **Name** to `CursorSubtitles`, **Identity Type** to Self Signed Root, **Certificate Type** to Code Signing
4. Click **Create**
5. Find the certificate in Keychain Access, double-click it, expand **Trust**, set **Code Signing** to **Always Trust** (enter your Mac login password when prompted)

The build script will automatically detect and use this certificate. This is entirely local — the certificate never leaves your machine.

## Configuration

Edit `~/.config/cursor-subtitles/config.json` to customize:

- `hotkey` — trigger shortcut (default: `cmd+/`)
- `style.backgroundColor` — pill color (hex, default: `#1F6BE8`)
- `style.textColor` — text color (hex, default: `#FFFFFF`)
- `style.placeholderText` — placeholder (default: `Say something`)
- `style.fontSize` — font size (default: `14`)
- `style.fontFamily` — font name or `system` (default: `system`)
- `style.cornerRadius` — pill roundness (default: `20`)
- `style.pointerCorner` — sharp top-left corner pointing at cursor (default: `true`)
- `style.paddingH` — horizontal padding (default: `16`)
- `style.paddingV` — vertical padding (default: `8`)
- `style.maxWidth` — max pill width (default: `300`)
- `style.cursorOffset.x` — horizontal offset from cursor (default: `12`)
- `style.cursorOffset.y` — vertical offset from cursor (default: `12`)
- `style.borderColor` — border color (hex, default: `#FFFFFF`)
- `style.borderOpacity` — border opacity 0–1 (default: `0.2`)
- `style.borderWidth` — border width (default: `2`)
- `style.shadowColor` — shadow color (hex, default: `#1049A7`)
- `style.shadowOpacity` — shadow opacity 0–1 (default: `0.1`)
- `style.shadowRadius` — shadow blur (default: `3`)
- `style.shadowX` — shadow horizontal offset (default: `0`)
- `style.shadowY` — shadow vertical offset (default: `5`)
- `behavior.idleTimeout` — seconds before fade (default: `10`)
- `behavior.fadeOutDuration` — fade out duration in seconds (default: `0.5`)
- `behavior.fadeInDuration` — fade in duration in seconds (default: `0.2`)
- `behavior.maxLines` — max line count (default: `5`)
- `behavior.charLimit` — max characters per line (default: `200`)

Changes apply instantly — no restart needed.

**After updating**, new config options won't appear in your existing config file. To get the latest defaults, delete the config and relaunch:

```bash
rm ~/.config/cursor-subtitles/config.json
```

The app will regenerate it with all current options. If you have custom values you want to keep, note them down first.

## Permissions

Requires **Accessibility** permission for global hotkey capture. The app will prompt on first launch.

## License

MIT
