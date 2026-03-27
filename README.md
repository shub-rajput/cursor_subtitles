<img width="124" height="124" alt="Cursor_subtitles_256x256" src="https://github.com/user-attachments/assets/54467e14-4770-4bcf-b6b8-7bb9d93e772f" />

# Pubbles


Subtitle bubbles for your pointer. A lightweight macOS menubar app that displays text bubbles below the pointer when enabled. Perfect for real-time context while screen recording for support, feedback and more! Requires **macOS 14.0+** (Sonoma or later).


![GH intro small](https://github.com/user-attachments/assets/96bee091-cb90-45b8-a058-9ccbdb3e4024)


<a href='https://ko-fi.com/U7U11CXDRK' target='_blank'><img height='42' style='border:0px;height:42px;' src='https://storage.ko-fi.com/cdn/kofi1.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>



## Install

### Homebrew (Recommended)

```bash
brew install --cask shub-rajput/pubbles/pubbles
```

### Install Script

Paste this in Terminal, downloads the latest release, removes the macOS quarantine flag, and moves the app to `/Applications`:

```bash
curl -fsSL https://raw.githubusercontent.com/shub-rajput/pubbles/main/scripts/install.sh | bash
```

### Manual

Download the latest `.zip` from [Releases](https://github.com/shub-rajput/pubbles/releases), unzip, and move `Pubbles.app` to `/Applications`.

> [!NOTE]
>macOS might show a warning and ask you to trash the app.
>That's because I haven't paid Apple $99/yr for the privilege of being a "verified" developer :) [(donate to support!)](https://ko-fi.com/shubhangrajput)
>Just close the prompt, then go to Settings > Privacy & Security > scroll down and click "Open Anyway"

### Build from Source

```bash
git clone https://github.com/shub-rajput/pubbles.git
cd pubbles
chmod +x scripts/build.sh
./scripts/build.sh
open Pubbles.app
```

## Usage

1. Press **Cmd+/** (editable) to activate the subtitle bubble
2. Type your text — it appears in a pill near your pointer
3. Press **Enter** for a new line (or wrap across multiple lines with multi-line mode on)
4. Press **Escape** or click anywhere to dismiss
5. The pill follows your pointer and fades after 10s of inactivity

### Doodle Mode

Press **Cmd+D** (editable) to toggle doodle mode — no need for the pill to be active first. When enabled:

- Hold **Cmd** and click+drag to draw on screen (red strokes by default)
- Release **Cmd** to stop drawing — type normally again
- Press **Cmd+/** while doodling to show the pill on top; press **Cmd+/** or **Escape** to reset everything
- A colored dot appears at the cursor while Cmd is held to indicate drawing is ready
- Drawing resets the idle timer — strokes and pill fade together
- Customize line color and width via `style.drawingLineColor` and `style.drawingLineWidth` in config
- The hold-modifier key (default: `cmd`) is configurable via `drawingHotkey` in config

### Settings

Open **Settings** from the menubar icon for a full settings window with tabs for Style, Hotkeys, General, and About.

<img width="770" height="639" alt="CleanShot 2026-03-27 at 10 51 11" src="https://github.com/user-attachments/assets/5863cfe9-cba8-445a-9f71-3c0cf24e61e4" />

### Keyboard Shortcuts

While the pill is active:

| Shortcut | Action |
|----------|--------|
| **Cmd+/** (editable) | Toggle pill on/off |
| **Cmd+D** (editable) | Toggle doodle mode on/off |
| **Cmd+Up** | Previous theme |
| **Cmd+Down** | Next theme |
| **Cmd+Right** | Scale pill up |
| **Cmd+Left** | Scale pill down |
| **Hold Cmd + click+drag** | Draw on screen (in doodle mode) |
| **Escape** | Dismiss pill |
| **Enter** | New line |

## Updating

### Homebrew

```bash
brew update && brew upgrade --cask pubbles
```

### Install Script

```bash
curl -fsSL https://raw.githubusercontent.com/shub-rajput/pubbles/main/scripts/install.sh | bash
```

Quits the running app, installs the latest release, and relaunches.

### Build from Source

```bash
./scripts/update.sh
```

This quits the app, pulls latest changes, rebuilds, and reopens. If you don't have a signing certificate, it will also reset permissions and prompt you to re-grant Accessibility access.

To avoid the permission prompt on every update, set up a signing certificate (see below).

## Signing Certificate (Recommended)

Without a local signing certificate, macOS invalidates Accessibility permission every time you rebuild. To avoid this:

1. Open **Keychain Access** (Spotlight → "Keychain Access")
2. Menu: **Keychain Access → Certificate Assistant → Create a Certificate...**
3. Set **Name** to `Pubbles`, **Identity Type** to Self Signed Root, **Certificate Type** to Code Signing
4. Click **Create**
5. Find the certificate in Keychain Access, double-click it, expand **Trust**, set **Code Signing** to **Always Trust** (enter your Mac login password when prompted)

The build script will automatically detect and use this certificate. This is entirely local — the certificate never leaves your machine.

## Themes

Switch themes from the menubar icon → **Theme**. Built-in themes:

- **Default** — solid blue pill with many color options to choose from (no theme selected)
- **Bold** — bold yellow with hard shadows and bold text
- **Candy** — pastel gradient with typewriter font
- **Frosted Glass** — translucent frosted blur
- **Liquid Glass** — Apple's native glass effect (macOS Tahoe/26+)
- **Midnight** — dark and minimal with charcoal gradient
- **Notepad** — warm parchment with Georgia serif
- **Terminal** — dark, green text, monospace font

When selecting Default theme you can quickly change the pill color from preset options.

### Custom Themes

Drop a `.json` file in `~/.config/pubbles/themes/` and it appears in the Theme menu. A theme file sets any style or behavior options:

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

Edit `~/.config/pubbles/config.json` to customize. The config file only needs to contain the values you want to change — everything else uses defaults (or theme values if a theme is active).

A minimal config looks like:

```json
{
  "hotkey": "cmd+/",
  "theme": "liquid-glass"
}
```

To override a theme's style, add specific keys under `style` or `behavior`:

```json
{
  "hotkey": "cmd+/",
  "theme": "terminal",
  "style": {
    "fontSize": 18
  }
}
```

### All Options

**Top-level:**
- `hotkey` — trigger shortcut (default: `cmd+/`)
- `drawingHotkey` — modifier key for hold-to-draw (default: `cmd`)
- `drawingToggleHotkey` — dedicated doodle mode toggle (default: `cmd+d`)
- `theme` — theme name matching a file in `~/.config/pubbles/themes/` (default: none)

**Style** (`style.*`):
- `backgroundColor` — pill color, hex (default: `#1F6BE8`)
- `backgroundOpacity` — background opacity 0–1 (default: `1.0`)
- `backgroundGradient` — array of hex colors for linear gradient, e.g. `["#6366F1", "#EC4899"]` (default: none)
- `vibrancy` — frosted blur material: `ultraThin`, `thin`, `regular`, `thick`, `ultraThick` (default: none)
- `glassEffect` — Apple Liquid Glass, macOS 26+ only (default: `false`)
- `textColor` — text color, hex (default: `#FFFFFF`)
- `placeholderText` — placeholder text (default: `Say something`)
- `fontSize` — font size (default: `14`)
- `pillScale` — overall pill scale, presets: `0.8`, `1.0`, `1.3`, `1.6`, `2.0` (default: `1.0`)
- `fontFamily` — font name or `system` (default: `system`)
- `fontWeight` — font weight: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` (default: `regular`)
- `cornerRadius` — pill roundness (default: `16`)
- `pointerCorner` — sharp top-left corner pointing at pointer (default: `true`)
- `paddingH` — horizontal padding (default: `12`)
- `paddingV` — vertical padding (default: `8`)
- `maxWidth` — max pill width (default: `300`)
- `cursorOffset.x` — horizontal offset from pointer (default: `12`)
- `cursorOffset.y` — vertical offset from pointer (default: `12`)
- `borderColor` — border color, hex (default: `#FFFFFF`)
- `borderOpacity` — border opacity 0–1 (default: `0.2`)
- `borderWidth` — border width (default: `2`)
- `shadowColor` — shadow color, hex (default: `#000000`)
- `shadowOpacity` — shadow opacity 0–1 (default: `0.1`)
- `shadowRadius` — shadow blur (default: `3`)
- `shadowX` — shadow horizontal offset (default: `0`)
- `shadowY` — shadow vertical offset (default: `5`)
- `drawingLineColor` — drawing stroke color, hex (default: `#FF0000`)
- `drawingLineWidth` — drawing stroke width (default: `3`)

**Behavior** (`behavior.*`):
- `idleTimeout` — seconds before fade (default: `10`)
- `fadeOutDuration` — fade out duration in seconds (default: `0.5`)
- `fadeInDuration` — fade in duration in seconds (default: `0.2`)
- `charLimit` — max characters per line, ignored when `multiLine` is on (default: `30`)
- `multiLine` — wrap text across multiple lines instead of a single scrolling line (default: `false`)

Changes apply instantly — no restart needed.

## Permissions

Requires **Accessibility** permission for global hotkey capture. The app will prompt on first launch.

## License

MIT
