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

## Themes

Switch themes from the menubar icon → **Theme**. Built-in themes:

- **Default** — solid blue pill (no theme selected)
- **Liquid Glass** — Apple's native glass effect (macOS Tahoe/26+)
- **Frosted Glass** — translucent frosted blur (macOS 13+)
- **Modern** — gradient background
- **Terminal** — dark, square corners, monospace font

When no theme is selected, a **Color** submenu lets you quickly change the pill color from preset options.

### Custom Themes

Drop a `.json` file in `~/.config/cursor-subtitles/themes/` and it appears in the Theme menu. A theme file sets any style or behavior options:

```json
{
  "name": "My Theme",
  "style": {
    "backgroundColor": "#FF6600",
    "textColor": "#FFFFFF",
    "cornerRadius": 8
  }
}
```

See the built-in themes in that directory for more examples.

## Configuration

Edit `~/.config/cursor-subtitles/config.json` to customize. The config file only needs to contain the values you want to change — everything else uses defaults (or theme values if a theme is active).

A minimal config looks like:

```json
{
  "hotkey": "cmd/",
  "theme": "liquid-glass"
}
```

To override a theme's style, add specific keys under `style` or `behavior`:

```json
{
  "hotkey": "cmd/",
  "theme": "terminal",
  "style": {
    "fontSize": 18
  }
}
```

### All Options

**Top-level:**
- `hotkey` — trigger shortcut (default: `cmd+/`)
- `theme` — theme name matching a file in `~/.config/cursor-subtitles/themes/` (default: none)

**Style** (`style.*`):
- `backgroundColor` — pill color, hex (default: `#1F6BE8`)
- `backgroundOpacity` — background opacity 0–1 (default: `1.0`)
- `backgroundGradient` — array of hex colors for linear gradient, e.g. `["#6366F1", "#EC4899"]` (default: none)
- `vibrancy` — frosted blur material: `ultraThin`, `thin`, `regular`, `thick`, `ultraThick` (default: none)
- `glassEffect` — Apple Liquid Glass, macOS 26+ only (default: `false`)
- `textColor` — text color, hex (default: `#FFFFFF`)
- `placeholderText` — placeholder text (default: `Say something`)
- `fontSize` — font size (default: `14`)
- `fontFamily` — font name or `system` (default: `system`)
- `fontWeight` — font weight: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` (default: `medium`)
- `cornerRadius` — pill roundness (default: `20`)
- `pointerCorner` — sharp top-left corner pointing at cursor (default: `true`)
- `paddingH` — horizontal padding (default: `16`)
- `paddingV` — vertical padding (default: `8`)
- `maxWidth` — max pill width (default: `300`)
- `cursorOffset.x` — horizontal offset from cursor (default: `12`)
- `cursorOffset.y` — vertical offset from cursor (default: `12`)
- `borderColor` — border color, hex (default: `#FFFFFF`)
- `borderOpacity` — border opacity 0–1 (default: `0.2`)
- `borderWidth` — border width (default: `2`)
- `shadowColor` — shadow color, hex (default: `#000000`)
- `shadowOpacity` — shadow opacity 0–1 (default: `0.1`)
- `shadowRadius` — shadow blur (default: `3`)
- `shadowX` — shadow horizontal offset (default: `0`)
- `shadowY` — shadow vertical offset (default: `5`)

**Behavior** (`behavior.*`):
- `idleTimeout` — seconds before fade (default: `10`)
- `fadeOutDuration` — fade out duration in seconds (default: `0.5`)
- `fadeInDuration` — fade in duration in seconds (default: `0.2`)
- `maxLines` — max line count (default: `5`)
- `charLimit` — max characters per line (default: `200`)

Changes apply instantly — no restart needed.

## Permissions

Requires **Accessibility** permission for global hotkey capture. The app will prompt on first launch.

## License

MIT
