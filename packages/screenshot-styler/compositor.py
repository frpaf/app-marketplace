"""Image composition engine — creates styled app store screenshots."""

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter


# ─── Default Configuration ──────────────────────────────────────────────────

CANVAS_WIDTH = 1080
CANVAS_HEIGHT = 1920
BG_COLOR = (55, 71, 90)
FRAME_COLOR = (30, 30, 30)
TEXT_COLOR = (255, 255, 255)
FONT_SIZE = 52
LINE_SPACING = 68
PHONE_BORDER = 16
CORNER_RADIUS = 40
SHADOW_OFFSET = 8
SHADOW_BLUR = 12
TEXT_Y_START = 80
PHONE_BOTTOM_MARGIN = 80


# ─── Bundled Font Path ──────────────────────────────────────────────────────

BUNDLED_FONT_DIR = Path(__file__).parent / "fonts"


# ─── Drawing Helpers ────────────────────────────────────────────────────────

def rounded_rect(draw: ImageDraw.Draw, xy: tuple, radius: int, fill) -> None:
    """Draw a rounded rectangle using pieslices for corners."""
    x0, y0, x1, y1 = xy
    d = 2 * radius
    draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
    draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
    draw.pieslice([x0, y0, x0 + d, y0 + d], 180, 270, fill=fill)
    draw.pieslice([x1 - d, y0, x1, y0 + d], 270, 360, fill=fill)
    draw.pieslice([x0, y1 - d, x0 + d, y1], 90, 180, fill=fill)
    draw.pieslice([x1 - d, y1 - d, x1, y1], 0, 90, fill=fill)


def get_font(size: int = FONT_SIZE) -> ImageFont.FreeTypeFont:
    """Find a bold font, checking bundled fonts first, then system paths."""
    # Bundled font (highest priority)
    bundled = BUNDLED_FONT_DIR / "DejaVuSans-Bold.ttf"
    if bundled.exists():
        return ImageFont.truetype(str(bundled), size)

    # System font paths
    system_paths = [
        # Linux
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
        # macOS
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        # Windows
        "C:\\Windows\\Fonts\\arialbd.ttf",
    ]
    for fp in system_paths:
        if os.path.exists(fp):
            try:
                return ImageFont.truetype(fp, size)
            except OSError:
                continue

    print("  WARNING: No suitable font found. Text may render poorly.")
    return ImageFont.load_default()


# ─── Main Composition ──────────────────────────────────────────────────────

def create_styled_screenshot(
    screenshot_path: str,
    output_path: str,
    text_lines: list[str],
    bg_color: tuple = BG_COLOR,
    font_size: int = FONT_SIZE,
) -> str:
    """
    Create a styled app store screenshot with phone frame and text.

    Args:
        screenshot_path: Path to the input screenshot (PNG/JPEG).
        output_path: Where to save the styled result.
        text_lines: List of text lines to display above the phone.
        bg_color: Background RGB tuple.
        font_size: Font size for the marketing text.

    Returns:
        The output_path on success.
    """
    screenshot = Image.open(screenshot_path)
    screen_aspect = screenshot.width / screenshot.height

    canvas = Image.new("RGB", (CANVAS_WIDTH, CANVAS_HEIGHT), bg_color)
    draw = ImageDraw.Draw(canvas)
    font = get_font(font_size)

    # ── Draw text ──
    num_lines = len(text_lines)
    y_start = TEXT_Y_START if num_lines <= 2 else 60
    line_spacing = LINE_SPACING if font_size == FONT_SIZE else int(font_size * 1.3)

    for i, line in enumerate(text_lines):
        bbox = draw.textbbox((0, 0), line, font=font)
        tw = bbox[2] - bbox[0]
        tx = (CANVAS_WIDTH - tw) // 2
        ty = y_start + i * line_spacing
        draw.text((tx, ty), line, fill=TEXT_COLOR, font=font)

    # ── Calculate phone dimensions ──
    text_block_bottom = y_start + num_lines * line_spacing + 40
    phone_top = text_block_bottom
    phone_bottom = CANVAS_HEIGHT - PHONE_BOTTOM_MARGIN
    phone_height = phone_bottom - phone_top

    phone_screen_h = phone_height - 2 * PHONE_BORDER
    phone_screen_w = int(phone_screen_h * screen_aspect)
    phone_frame_w = phone_screen_w + 2 * PHONE_BORDER
    phone_x = (CANVAS_WIDTH - phone_frame_w) // 2
    phone_y = phone_top

    # Clamp phone width to canvas
    if phone_frame_w > CANVAS_WIDTH - 40:
        phone_frame_w = CANVAS_WIDTH - 40
        phone_screen_w = phone_frame_w - 2 * PHONE_BORDER
        phone_screen_h = int(phone_screen_w / screen_aspect)
        phone_height = phone_screen_h + 2 * PHONE_BORDER
        phone_x = (CANVAS_WIDTH - phone_frame_w) // 2
        # Re-center vertically in remaining space
        phone_y = text_block_bottom + ((phone_bottom - text_block_bottom) - phone_height) // 2

    # ── Draw shadow ──
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    rounded_rect(
        shadow_draw,
        (
            phone_x + SHADOW_OFFSET,
            phone_y + SHADOW_OFFSET,
            phone_x + phone_frame_w + SHADOW_OFFSET,
            phone_y + phone_height + SHADOW_OFFSET,
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
        (phone_x, phone_y, phone_x + phone_frame_w, phone_y + phone_height),
        CORNER_RADIUS,
        FRAME_COLOR,
    )

    # ── Place screenshot inside frame ──
    screen_x = phone_x + PHONE_BORDER
    screen_y = phone_y + PHONE_BORDER
    resized = screenshot.resize((phone_screen_w, phone_screen_h), Image.LANCZOS)

    # Rounded corners mask for the screenshot
    inner_r = max(CORNER_RADIUS - PHONE_BORDER, 8)
    mask = Image.new("L", (phone_screen_w, phone_screen_h), 0)
    mask_draw = ImageDraw.Draw(mask)
    rounded_rect(mask_draw, (0, 0, phone_screen_w, phone_screen_h), inner_r, 255)

    canvas.paste(resized, (screen_x, screen_y), mask)

    # ── Save ──
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    canvas.save(output_path, "PNG")
    size_kb = os.path.getsize(output_path) / 1024
    print(f"  Saved: {output_path} ({CANVAS_WIDTH}x{CANVAS_HEIGHT}, {size_kb:.0f} KB)")

    return output_path
