# Echo Macro - OpenDeck Plugin

A simple OpenDeck plugin that types pre-recorded text when you press a Stream Deck button.

## What It Does

- Assign text to a Stream Deck button
- When pressed, the plugin "types" that text as if you typed it on your keyboard
- Works on **Linux (Wayland & X11)**, macOS, and Windows
- Privacy-friendly: text content is masked in logs (best effort - see [Privacy Note](#privacy-note))

## Requirements

### Linux (Wayland or X11)

You need **`ydotool`** installed:

```bash
# Fedora
sudo dnf install ydotool

# Ubuntu/Debian
sudo apt install ydotool

# Arch
sudo pacman -S ydotool
```

And the **`ydotoold` daemon must be running**:

```bash
# Start the daemon
ydotoold

# Or as a systemd service (if available)
systemctl --user start ydotoold
```

### macOS & Windows

The plugin uses native APIs and doesn't require additional dependencies.

## Building

### Prerequisites

- **Rust** (latest stable): https://rustup.rs/
- **OpenDeck**: https://github.com/nekename/OpenDeck

### Quick Build

```bash
cd echo-macro
./build.sh
```

### Manual Build

```bash
cargo build --release
mkdir -p build/net.ashurtech.echo-macro.sdPlugin
cp manifest.json property-inspector.html target/release/echo-macro build/net.ashurtech.echo-macro.sdPlugin/
```

## Installation

### Easy Install

```bash
./build.sh --install
```

This auto-detects OpenDeck location (including Flatpak installs).

### Manual Installation

**Linux (native):**
```bash
cp -r build/net.ashurtech.echo-macro.sdPlugin ~/.config/opendeck/plugins/
```

**Linux (Flatpak):**
```bash
cp -r build/net.ashurtech.echo-macro.sdPlugin \
  ~/.var/app/me.amankhanna.opendeck/config/opendeck/plugins/
```

**macOS:**
```bash
cp -r build/net.ashurtech.echo-macro.sdPlugin \
  ~/Library/Application\ Support/opendeck/plugins/
```

**Windows:**
```powershell
Copy-Item -Recurse build/net.ashurtech.echo-macro.sdPlugin `
  "$env:APPDATA\opendeck\plugins\"
```

Then restart OpenDeck or click "Reload Plugins".

## Usage

1. Open OpenDeck
2. Drag the "Type Text" action to a button
3. Click the button to open the Property Inspector
4. Enter the text you want to type
5. Click outside the Property Inspector to save
6. Press the Stream Deck button - text appears!

**Default behavior:** If you don't configure any text, it will type "Hello World".

## Flatpak Support

If running OpenDeck as Flatpak, the plugin automatically detects this and uses `flatpak-spawn --host` to access ydotool on the host system. You may need to grant the permission:

```bash
flatpak override --user --talk-name=org.freedesktop.Flatpak me.amankhanna.opendeck
```

## Project Structure

```
echo-macro/
├── build.sh                # Build script
├── justfile                # Just commands
├── Cargo.toml              # Rust dependencies
├── manifest.json           # Plugin metadata
├── property-inspector.html # Settings UI
├── README.md               # This file
├── icon.png                # Plugin icon
└── src/
    └── main.rs             # Main plugin code
```

## Code Overview

- **`openaction`**: OpenDeck's Rust SDK for WebSocket communication
- **`ydotool`**: Wayland/X11 compatible input simulation (Linux)
- **`serde`**: JSON parsing for settings
- **`tokio`**: Async runtime

### Key Files

**`src/main.rs`**
- `TypeTextSettings`: User configuration
- `EchoMacroHandler`: Action event handler
- `type_text()`: Types text using ydotool (Linux) or native APIs

**`property-inspector.html`**
- Simple text input UI
- Saves settings to OpenDeck

## Troubleshooting

### Plugin doesn't appear in OpenDeck
- Check OpenDeck logs: `~/.local/share/opendeck/logs/latest.log`
- Ensure `manifest.json` is valid JSON
- Verify binary has execute permissions: `chmod +x echo-macro`

### Text isn't being typed (Linux)
- **Make sure `ydotoold` is running**: `pgrep ydotoold`
- **Check ydotool works**: `ydotool type "test"`
- **Flatpak users**: Ensure `ydotool` is installed on the **host** system, not inside Flatpak
- Check logs: `~/.local/share/opendeck/logs/plugins/net.ashurtech.echo-macro.log`

### Settings not saving
- Click outside the Property Inspector to save
- Check browser console in the PI (right-click → Inspect Element)

## GitHub Actions

This repo includes a GitHub Actions workflow that automatically builds and releases the plugin when you push a tag starting with `v`:

```bash
# Tag a new version
git tag v1.0.1
git push origin v1.0.1

# GitHub Actions will automatically:
# - Build the Rust binary
# - Create the .sdPlugin bundle
# - Create a GitHub release with the plugin package
```

You can also manually trigger a release from the Actions tab.

## Privacy Note

This plugin attempts to mask text content in logs to protect sensitive information (passwords, API keys, etc.). However, this is a **best-effort feature**:

- **Normal operation**: Text is masked (e.g., `H... (5 chars)` or `H***************d (20 chars)`)
- **Debug mode**: If you enable debug logging, the raw text may appear in logs from the underlying SDK

**Recommendation**: Do not enable debug mode in production if typing sensitive data. The masking is designed for regular usage at default log levels.

## License

MIT - Feel free to modify and share!

## Resources

- [OpenDeck on GitHub](https://github.com/nekename/OpenDeck)
- [OpenAction Crate](https://docs.rs/openaction/) - Rust SDK docs
- [ydotool](https://github.com/ReimuNotMoe/ydotool) - Linux input tool
