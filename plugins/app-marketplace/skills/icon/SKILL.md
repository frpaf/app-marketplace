---
name: google-play-icon
version: 1.0.0
description: Generate Google Play Store compliant app icons from source images. Use when user wants to create, convert, resize, or prepare an app icon for Google Play Store upload.
triggers:
  - play store icon
  - android app icon
  - adaptive icon
  - app store icon
  - icon specifications
  - google play icon
  - 512x512 icon
  - app icon background
tools:
  - bash
  - read
---

# Google Play Store Icon Generator

Generate Play Store compliant 512x512 app icons from source images with automatic background detection and replacement.

## Google Play Icon Specifications

| Requirement | Value |
|-------------|-------|
| Dimensions | 512 x 512 px |
| Format | 32-bit PNG (RGBA) |
| Color space | sRGB |
| Max file size | 1 MB |
| Shape | Full square (no rounded corners) |
| Shadows | None (Google applies rounding and shadow) |
| Alpha | Allowed but no transparency at edges |

## Workflow

### Step 0 — Check dependencies (run every time)

Before doing anything else, verify that Python 3 and Pillow are installed:

```bash
python3 --version && python3 -c "from PIL import Image; print('Pillow OK')"
```

**If Python 3 is missing**, guide the user to install it:
- **macOS**: `brew install python` or download from https://www.python.org/downloads/
- **Windows**: Download from https://www.python.org/downloads/ — check "Add Python to PATH" during install
- **Linux**: `sudo apt update && sudo apt install python3 python3-pip`

**If Pillow is missing**, install it:
```bash
pip3 install Pillow
```
If permission error: `pip3 install --user Pillow`

Re-run the check above after installation. Do NOT proceed until both dependencies are confirmed working.

### Step 1 — Inspect source image
Read the source image to determine dimensions, format, and background color.

### Step 2 — Ask about background color
If the source has a transparent or non-white background, ask user what background color to use.

### Step 3 — Run icon generation script
Execute `scripts/generate_icon.py` with appropriate options.

### Step 4 — Verify output
Check the output is 512x512 PNG under 1MB.

### Step 5 — Present result
Show the user the output path and file details.

## Usage

```bash
# Basic: resize and set white background
python3 skills/google-play-icon/scripts/generate_icon.py source.png output_icon.png

# Custom background color (RGB values)
python3 skills/google-play-icon/scripts/generate_icon.py source.png output_icon.png --bg-color 25 25 112

# Skip background replacement (full-bleed artwork)
python3 skills/google-play-icon/scripts/generate_icon.py source.png output_icon.png --no-replace

# Specify the color to replace (instead of auto-detect)
python3 skills/google-play-icon/scripts/generate_icon.py source.png output_icon.png --replace-color 0 0 0 --bg-color 255 255 255

# Adjust color matching threshold (default: 15)
python3 skills/google-play-icon/scripts/generate_icon.py source.png output_icon.png --threshold 30
```

## Design Guidelines

### Full-Bleed vs Keyline Grid

- **Full-bleed**: Artwork fills the entire 512x512 canvas. Use `--no-replace`.
- **Keyline grid**: Logo centered on a solid background. The script auto-detects and replaces the background color.

### Adaptive Icon Foreground

If the source is an adaptive icon foreground layer (typically has a transparent or solid color background):
1. The script auto-detects the background color by sampling edge pixels
2. Replaces that color with the specified `--bg-color` (default: white)
3. Resizes to 512x512

### Best Practices

- Source image should be at least 512x512 for best quality
- Use PNG or high-quality JPEG as source
- For logos on solid backgrounds, let the script auto-detect and replace the background
- For photographic or full-bleed icons, use `--no-replace`

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Source already 512x512 | Still processes (background replacement, format conversion) |
| Source smaller than 512x512 | Upscales with LANCZOS — warns if source < 256px |
| Output exceeds 1MB | Automatically optimizes PNG compression |
| Source is JPEG (no alpha) | Converts to RGBA, processes normally |
| Source is SVG | Not supported — convert to PNG first |
| Source has complex gradients at edges | Increase `--threshold` or use `--no-replace` |

## Dependencies

- Python 3
- Pillow (`pip install Pillow`)

## $ARGUMENTS

Pass arguments after the skill name:
```
/google-play-icon source_image.png --bg-color 255 255 255
```
