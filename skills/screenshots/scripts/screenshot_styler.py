#!/usr/bin/env python3
"""
Screenshot Styler — Creates app store-ready screenshots with phone frames
and marketing text overlay.

Takes raw app screenshots and produces styled images with:
- Configurable background color (default: dark blue-grey)
- Phone frame with rounded corners and drop shadow
- Marketing text centered above the phone frame
- Output meeting store size requirements (1080x1920 default, configurable presets)

Text sources (in priority order):
1. --config JSON file with per-screenshot text
2. --captions-json from the app-store-screenshots organize_output.py
3. --text manual override (applies to all screenshots)
4. Claude API vision-based generation (requires ANTHROPIC_API_KEY)
5. Filename-derived fallback
"""

import os
import sys
import json
import base64
import argparse
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:
    print("Error: Pillow is required. Install with: pip install Pillow", file=sys.stderr)
    sys.exit(1)


# ─── Size Presets ────────────────────────────────────────────────────────────

PRESETS = {
    "phone-portrait":       (1080, 1920),   # Default, Play Store phone
    "phone-landscape":      (1920, 1080),   # Landscape screenshots
    "iphone-6.9":           (1320, 2868),   # iPhone 16 Pro Max (App Store)
    "iphone-6.5":           (1242, 2688),   # iPhone 11 Pro Max (App Store)
    "ipad-13":              (2064, 2752),   # iPad Pro 13" portrait (App Store)
    "ipad-13-landscape":    (2752, 2064),   # iPad Pro 13" landscape (App Store)
    "ipad-12.9":            (2048, 2732),   # iPad Pro 12.9" portrait (App Store)
    "ipad-12.9-landscape":  (2732, 2048),   # iPad Pro 12.9" landscape (App Store)
    "tablet-7":             (1080, 1920),   # Android 7" tablet
    "tablet-10":            (1200, 1920),   # Android 10" tablet
}

# ─── Defaults ────────────────────────────────────────────────────────────────

DEFAULT_BG_COLOR = (55, 71, 90)
FRAME_COLOR = (30, 30, 30)
TEXT_COLOR = (255, 255, 255)
DEFAULT_FONT_SIZE = 52
LINE_SPACING_RATIO = 1.3
PHONE_BORDER = 16
CORNER_RADIUS = 40
SHADOW_OFFSET = 8
SHADOW_BLUR = 12
TEXT_Y_START = 80
PHONE_BOTTOM_MARGIN = 80
MODEL = "claude-sonnet-4-20250514"


# ─── Drawing Helpers ─────────────────────────────────────────────────────────

def rounded_rect(draw, xy, radius, fill):
    """Draw a rounded rectangle."""
    x0, y0, x1, y1 = xy
    draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
    draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
    draw.pieslice([x0, y0, x0 + 2*radius, y0 + 2*radius], 180, 270, fill=fill)
    draw.pieslice([x1 - 2*radius, y0, x1, y0 + 2*radius], 270, 360, fill=fill)
    draw.pieslice([x0, y1 - 2*radius, x0 + 2*radius, y1], 90, 180, fill=fill)
    draw.pieslice([x1 - 2*radius, y1 - 2*radius, x1, y1], 0, 90, fill=fill)


def get_font(size):
    """Find and return a bold font, searching common paths."""
    font_paths = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
        "C:\\Windows\\Fonts\\arialbd.ttf",
    ]
    for fp in font_paths:
        if os.path.exists(fp):
            return ImageFont.truetype(fp, size)
    return ImageFont.load_default()


# ─── Text Generation (Claude API) ───────────────────────────────────────────

def generate_text_for_screenshot(image_path, lang="en"):
    """Use Claude vision API to generate marketing text for a screenshot."""
    try:
        import anthropic
    except ImportError:
        print("  anthropic SDK not installed — using filename fallback", file=sys.stderr)
        return None

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("  ANTHROPIC_API_KEY not set — using filename fallback", file=sys.stderr)
        return None

    client = anthropic.Anthropic()

    with open(image_path, "rb") as f:
        image_data = base64.standard_b64encode(f.read()).decode("utf-8")

    ext = Path(image_path).suffix.lower()
    media_type = "image/png" if ext == ".png" else "image/jpeg"

    lang_instruction = {
        "en": "in English",
        "da": "in Danish (Dansk)",
        "de": "in German (Deutsch)",
        "sv": "in Swedish (Svenska)",
        "no": "in Norwegian (Norsk)",
    }.get(lang, f"in {lang}")

    response = client.messages.create(
        model=MODEL,
        max_tokens=200,
        messages=[{
            "role": "user",
            "content": [
                {
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": media_type,
                        "data": image_data,
                    },
                },
                {
                    "type": "text",
                    "text": (
                        f"Look at this mobile app screenshot and generate a short, "
                        f"catchy marketing title {lang_instruction} that describes "
                        f"what the user can do on this screen.\n\n"
                        f"Rules:\n"
                        f"- Maximum 2 lines of text\n"
                        f"- Each line should be max 25 characters\n"
                        f"- The text should be suitable for an app store listing\n"
                        f"- Focus on the user benefit/action, not technical details\n"
                        f"- Use title case\n\n"
                        f'Return ONLY a JSON array of strings, one per line. '
                        f'Example: ["Record Incidents", "Quickly and Efficiently"]'
                    ),
                },
            ],
        }],
    )

    text = response.content[0].text.strip()
    try:
        lines = json.loads(text)
        if isinstance(lines, list):
            return [str(line) for line in lines]
    except json.JSONDecodeError:
        pass

    return [line.strip().strip('"').strip("'") for line in text.split("\n") if line.strip()]


# ─── Text & Language Resolution ──────────────────────────────────────────────

def get_screenshot_language(filename, captions_data):
    """Get the detected language for a screenshot from captions.json."""
    if not captions_data:
        return None
    for screenshot in captions_data.get("screenshots", []):
        if screenshot.get("filename") == filename:
            return screenshot.get("detected_language")
    return None


def get_all_languages(captions_data):
    """Get the set of all detected languages from captions.json."""
    if not captions_data:
        return set()
    langs = set()
    for screenshot in captions_data.get("screenshots", []):
        lang = screenshot.get("detected_language")
        if lang:
            langs.add(lang)
    return langs


def resolve_text(filename, lang, config, captions_data, custom_text):
    """Resolve text lines for a screenshot from available sources."""

    # 1. Config file override
    if config:
        screenshots_config = config.get("screenshots", {})
        entry = screenshots_config.get(filename)
        if entry and lang in entry:
            return entry[lang]

    # 2. Captions JSON (from organize_output.py)
    if captions_data:
        for screenshot in captions_data.get("screenshots", []):
            if screenshot.get("filename") == filename:
                captions = screenshot.get("captions", {})
                # Use play_store short caption, or app_store caption
                play = captions.get("play_store", {})
                apple = captions.get("app_store", {})
                text = play.get("short") or apple.get("caption")
                if text:
                    return [text]

    # 3. Manual text override
    if custom_text:
        return [line.strip() for line in custom_text.split("\\n")]

    return None  # Will trigger API generation or fallback


# ─── Image Composition ──────────────────────────────────────────────────────

def create_styled_screenshot(
    screenshot_path,
    output_path,
    text_lines,
    bg_color=DEFAULT_BG_COLOR,
    canvas_size=None,
    font_size=DEFAULT_FONT_SIZE,
):
    """Create a styled app store screenshot with phone frame and text."""

    if canvas_size is None:
        canvas_size = PRESETS["phone-portrait"]

    canvas_w, canvas_h = canvas_size
    line_spacing = int(font_size * LINE_SPACING_RATIO)

    screenshot = Image.open(screenshot_path)
    screen_aspect = screenshot.width / screenshot.height

    canvas = Image.new("RGB", (canvas_w, canvas_h), bg_color)
    draw = ImageDraw.Draw(canvas)
    font = get_font(font_size)

    # ── Draw text ──
    num_lines = len(text_lines)
    y_start = TEXT_Y_START if num_lines <= 2 else 60

    for i, line in enumerate(text_lines):
        bbox = draw.textbbox((0, 0), line, font=font)
        tw = bbox[2] - bbox[0]
        tx = (canvas_w - tw) // 2
        ty = y_start + i * line_spacing
        draw.text((tx, ty), line, fill=TEXT_COLOR, font=font)

    # ── Calculate phone dimensions ──
    phone_top = y_start + num_lines * line_spacing + 60
    phone_bottom = canvas_h - PHONE_BOTTOM_MARGIN
    phone_height = phone_bottom - phone_top

    phone_screen_h = phone_height - 2 * PHONE_BORDER
    phone_screen_w = int(phone_screen_h * screen_aspect)
    phone_frame_w = phone_screen_w + 2 * PHONE_BORDER
    phone_frame_h = phone_height
    phone_x = (canvas_w - phone_frame_w) // 2
    phone_y = phone_top

    # ── Draw shadow ──
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    rounded_rect(
        shadow_draw,
        (
            phone_x + SHADOW_OFFSET,
            phone_y + SHADOW_OFFSET,
            phone_x + phone_frame_w + SHADOW_OFFSET,
            phone_y + phone_frame_h + SHADOW_OFFSET,
        ),
        CORNER_RADIUS,
        (0, 0, 0, 80),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    canvas.paste(
        Image.composite(
            shadow,
            Image.new("RGBA", canvas.size, (0, 0, 0, 0)),
            shadow,
        ).convert("RGB"),
        mask=shadow.split()[3],
    )

    # ── Draw phone frame ──
    draw = ImageDraw.Draw(canvas)
    rounded_rect(
        draw,
        (phone_x, phone_y, phone_x + phone_frame_w, phone_y + phone_frame_h),
        CORNER_RADIUS,
        FRAME_COLOR,
    )

    # ── Place screenshot ──
    screen_x = phone_x + PHONE_BORDER
    screen_y = phone_y + PHONE_BORDER
    resized = screenshot.resize((phone_screen_w, phone_screen_h), Image.LANCZOS)

    mask = Image.new("L", (phone_screen_w, phone_screen_h), 0)
    mask_draw = ImageDraw.Draw(mask)
    inner_r = max(CORNER_RADIUS - PHONE_BORDER, 8)
    rounded_rect(mask_draw, (0, 0, phone_screen_w, phone_screen_h), inner_r, 255)

    canvas.paste(resized, (screen_x, screen_y), mask)

    # ── Save ──
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    canvas.save(output_path, "PNG", optimize=True)
    size_kb = os.path.getsize(output_path) / 1024
    print(f"  Saved: {output_path} ({canvas_w}x{canvas_h}, {size_kb:.0f} KB)")

    return output_path


# ─── Batch Processing ───────────────────────────────────────────────────────

def process_screenshots(
    input_path,
    output_dir,
    lang=None,
    custom_text=None,
    bg_color=DEFAULT_BG_COLOR,
    config=None,
    captions_data=None,
    preset="phone-portrait",
    font_size=DEFAULT_FONT_SIZE,
):
    """Process all screenshots in a folder or a single file.

    Language handling:
    - If --lang is set, all screenshots use that language (overrides auto-detection)
    - If captions.json has detected_language per screenshot, use that
    - If multiple languages detected, output is organized into per-language folders
    - Falls back to 'en' if no language can be determined
    """

    os.makedirs(output_dir, exist_ok=True)
    input_path = Path(input_path)
    canvas_size = PRESETS.get(preset, PRESETS["phone-portrait"])

    if input_path.is_file():
        files = [input_path]
    else:
        files = sorted(
            f
            for f in input_path.iterdir()
            if f.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")
        )

    if not files:
        print(f"No image files found in {input_path}")
        return []

    # Determine if we need per-language folders
    detected_languages = get_all_languages(captions_data) if captions_data else set()
    use_lang_folders = not lang and len(detected_languages) > 1

    if use_lang_folders:
        print(f"\nMultiple languages detected: {', '.join(sorted(detected_languages))}")
        print(f"Output will be organized into per-language folders.\n")

    print(f"Processing {len(files)} screenshot(s) -> {preset} ({canvas_size[0]}x{canvas_size[1]})\n")

    results = []
    for i, filepath in enumerate(files, 1):
        print(f"[{i}/{len(files)}] {filepath.name}")

        # Determine language for this screenshot
        if lang:
            # --lang flag overrides everything
            screenshot_lang = lang
        else:
            # Auto-detect from captions.json
            screenshot_lang = get_screenshot_language(filepath.name, captions_data) or "en"

        print(f"  Language: {screenshot_lang}")

        # Resolve text
        lines = resolve_text(filepath.name, screenshot_lang, config, captions_data, custom_text)

        if lines is None:
            # Try Claude API with detected language
            print(f"  Generating text ({screenshot_lang})...")
            try:
                lines = generate_text_for_screenshot(str(filepath), screenshot_lang)
            except Exception as e:
                print(f"  API error: {e}")
                lines = None

        if lines is None:
            # Final fallback: derive from filename
            lines = [filepath.stem.replace("_", " ").replace("-", " ").title()]

        print(f"  Text: {' / '.join(lines)}")

        # Determine output path (with or without language subfolder)
        if use_lang_folders:
            lang_output_dir = str(Path(output_dir) / screenshot_lang)
            os.makedirs(lang_output_dir, exist_ok=True)
            output_name = f"{filepath.stem}_styled.png"
            output_path = str(Path(lang_output_dir) / output_name)
        else:
            output_name = f"{filepath.stem}_styled.png"
            output_path = str(Path(output_dir) / output_name)

        create_styled_screenshot(
            str(filepath),
            output_path,
            lines,
            bg_color=bg_color,
            canvas_size=canvas_size,
            font_size=font_size,
        )
        results.append(output_path)

    print(f"\nDone! {len(results)} styled screenshot(s) saved to {output_dir}/")
    if use_lang_folders:
        for detected_lang in sorted(detected_languages):
            lang_count = sum(1 for r in results if f"/{detected_lang}/" in r)
            print(f"  {detected_lang}/: {lang_count} screenshot(s)")
    print()
    return results


def generate_config(input_path, output_path, lang="en"):
    """Generate a config file by running Claude API on all screenshots."""
    input_path = Path(input_path)

    if input_path.is_file():
        files = [input_path]
    else:
        files = sorted(
            f
            for f in input_path.iterdir()
            if f.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")
        )

    config = {
        "defaults": {
            "bg_color": list(DEFAULT_BG_COLOR),
            "font_size": DEFAULT_FONT_SIZE,
        },
        "screenshots": {},
    }

    print(f"\nGenerating config for {len(files)} screenshot(s)...\n")

    for i, filepath in enumerate(files, 1):
        print(f"[{i}/{len(files)}] {filepath.name}")
        try:
            lines = generate_text_for_screenshot(str(filepath), lang)
            if lines:
                config["screenshots"][filepath.name] = {lang: lines}
                print(f"  -> {' / '.join(lines)}")
            else:
                config["screenshots"][filepath.name] = {
                    lang: [filepath.stem.replace("_", " ").title()]
                }
                print(f"  -> (fallback) {filepath.stem.replace('_', ' ').title()}")
        except Exception as e:
            print(f"  Error: {e}")
            config["screenshots"][filepath.name] = {
                lang: [filepath.stem.replace("_", " ").title()]
            }

    with open(output_path, "w") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)

    print(f"\nConfig saved to {output_path}")
    print("Edit the text entries, then use --config to apply them.\n")


# ─── CLI ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Create app store-ready screenshots with phone frames and marketing text"
    )
    parser.add_argument("--input", "-i", required=True,
                        help="Input screenshot file or folder")
    parser.add_argument("--output", "-o", required=True,
                        help="Output directory for styled screenshots")
    parser.add_argument("--lang", "-l", default=None,
                        help="Force language for all text overlays (overrides auto-detection from captions.json). If not set, uses detected_language per screenshot.")
    parser.add_argument("--text", "-t", default=None,
                        help="Custom text override (use \\n for line breaks)")
    parser.add_argument("--bg-color", default=None,
                        help="Background color as 'R,G,B' (default: '55,71,90')")
    parser.add_argument("--config", "-c", default=None,
                        help="Path to JSON config file with per-screenshot text")
    parser.add_argument("--captions-json", default=None,
                        help="Path to captions.json from organize_output.py")
    parser.add_argument("--preset", "-p", default="phone-portrait",
                        choices=list(PRESETS.keys()),
                        help="Size preset (default: phone-portrait)")
    parser.add_argument("--font-size", type=int, default=DEFAULT_FONT_SIZE,
                        help="Font size for overlay text (default: 52)")
    parser.add_argument("--generate-config", default=None, metavar="OUTPUT_JSON",
                        help="Generate a config file from AI analysis (review before using)")

    args = parser.parse_args()

    # Generate config mode
    if args.generate_config:
        generate_config(args.input, args.generate_config, args.lang or "en")
        return

    # Parse bg color
    bg_color = DEFAULT_BG_COLOR
    if args.bg_color:
        try:
            bg_color = tuple(int(x) for x in args.bg_color.split(","))
        except ValueError:
            print(f"Error: Invalid --bg-color format: {args.bg_color}", file=sys.stderr)
            sys.exit(1)

    # Load config file
    config = None
    if args.config:
        with open(args.config) as f:
            config = json.load(f)
        # Apply config defaults
        defaults = config.get("defaults", {})
        if "bg_color" in defaults and not args.bg_color:
            bg_color = tuple(defaults["bg_color"])

    # Load captions JSON
    captions_data = None
    if args.captions_json:
        with open(args.captions_json) as f:
            captions_data = json.load(f)

    process_screenshots(
        args.input,
        args.output,
        lang=args.lang,
        custom_text=args.text,
        bg_color=bg_color,
        config=config,
        captions_data=captions_data,
        preset=args.preset,
        font_size=args.font_size,
    )


if __name__ == "__main__":
    main()
