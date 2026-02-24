# agent-device Command Reference

Quick reference for `agent-device` CLI commands used during app exploration.

## App Lifecycle

| Command | Description |
|---------|-------------|
| `agent-device open <bundle-id> --platform <ios\|android>` | Launch app on simulator/emulator |
| `agent-device close` | Close the current app |

## Snapshots & Screenshots

| Command | Description |
|---------|-------------|
| `agent-device snapshot` | Get accessibility tree of current screen |
| `agent-device snapshot -i` | Interactive snapshot — shows element IDs (`@eN`) for clicking |
| `agent-device screenshot <path.png>` | Capture current screen as PNG |

## Interactions

| Command | Description |
|---------|-------------|
| `agent-device click @eN` | Tap element by ID from snapshot |
| `agent-device click X Y` | Tap at coordinates (fallback) |
| `agent-device fill @eN "text"` | Fill text into an input field |
| `agent-device scroll up\|down\|left\|right` | Scroll in specified direction |
| `agent-device type "text"` | Type text (keyboard input) |
| `agent-device key back` | Press back/navigation key |
| `agent-device get @eN` | Get element properties |

## Semantic Search

| Command | Description |
|---------|-------------|
| `agent-device find "description"` | Find elements matching a description |

## Recording & Replay

| Command | Description |
|---------|-------------|
| `agent-device record` | Start recording interactions |
| `agent-device replay <recording>` | Replay recorded interactions |
| `agent-device replay --update <recording>` | Replay and update element references |

## Tips

- **Always snapshot after actions** — the screen state may have changed
- **Use `-i` flag** on snapshots to see interactive element IDs
- **Use descriptive filenames** for screenshots (e.g., `03_settings.png` not `screen3.png`)
- **Fallback to coordinates** if element IDs aren't working (`agent-device click 200 450`)
- **Wait for animations** — take a snapshot to verify the screen has settled before capturing
- **Check for modals/overlays** — dismiss any popups before capturing the main content
