#!/usr/bin/env python3
"""Generate Google Play Store compliant 512x512 app icons from source images.

Features:
- Auto-detect background color by sampling edge pixels
- Replace background color within configurable threshold
- Resize to 512x512 with LANCZOS resampling
- Output as 32-bit PNG (RGBA), optimize if >1MB
"""

import argparse
import sys
import os

try:
    from PIL import Image
except ImportError:
    print("Error: Pillow is required. Install with: pip install Pillow", file=sys.stderr)
    sys.exit(1)


TARGET_SIZE = (512, 512)
MAX_FILE_SIZE = 1_000_000  # 1MB


def sample_edge_pixels(img, sample_count=40):
    """Sample pixels along the edges of the image to detect background color."""
    width, height = img.size
    pixels = []

    for i in range(sample_count):
        # Top edge
        x = int(i * (width - 1) / (sample_count - 1))
        pixels.append(img.getpixel((x, 0)))
        # Bottom edge
        pixels.append(img.getpixel((x, height - 1)))
        # Left edge
        y = int(i * (height - 1) / (sample_count - 1))
        pixels.append(img.getpixel((0, y)))
        # Right edge
        pixels.append(img.getpixel((width - 1, y)))

    return pixels


def detect_background_color(img):
    """Detect the most common color along image edges."""
    pixels = sample_edge_pixels(img)

    # Normalize to RGB (ignore alpha)
    rgb_pixels = []
    for p in pixels:
        if len(p) == 4:
            r, g, b, a = p
            if a < 128:
                rgb_pixels.append((0, 0, 0, 0))  # transparent
            else:
                rgb_pixels.append((r, g, b))
        else:
            rgb_pixels.append(p[:3])

    # Check if mostly transparent
    transparent_count = sum(1 for p in rgb_pixels if len(p) == 4 and p[3] == 0)
    if transparent_count > len(rgb_pixels) * 0.6:
        return None  # transparent background

    # Filter out transparent markers
    solid_pixels = [p for p in rgb_pixels if len(p) == 3]
    if not solid_pixels:
        return None

    # Find most common color (simple frequency count)
    color_counts = {}
    for p in solid_pixels:
        # Quantize to reduce noise (round to nearest 8)
        quantized = (p[0] // 8 * 8, p[1] // 8 * 8, p[2] // 8 * 8)
        color_counts[quantized] = color_counts.get(quantized, 0) + 1

    most_common = max(color_counts, key=color_counts.get)
    return most_common


def color_distance(c1, c2):
    """Calculate Euclidean distance between two RGB colors."""
    return ((c1[0] - c2[0]) ** 2 + (c1[1] - c2[1]) ** 2 + (c1[2] - c2[2]) ** 2) ** 0.5


def replace_background(img, old_color, new_color, threshold=15):
    """Replace background color in image."""
    img = img.convert("RGBA")
    pixels = img.load()
    width, height = img.size
    replaced = 0

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a < 128:
                # Transparent pixel -> fill with new color
                pixels[x, y] = (new_color[0], new_color[1], new_color[2], 255)
                replaced += 1
            elif old_color and color_distance((r, g, b), old_color) <= threshold:
                pixels[x, y] = (new_color[0], new_color[1], new_color[2], 255)
                replaced += 1

    total = width * height
    print(f"  Replaced {replaced}/{total} pixels ({replaced * 100 / total:.1f}%)")
    return img


def generate_icon(input_path, output_path, bg_color=(255, 255, 255),
                  replace_color=None, threshold=15, no_replace=False):
    """Generate a Play Store compliant icon."""

    # Load image
    print(f"Loading: {input_path}")
    img = Image.open(input_path)
    print(f"  Source: {img.size[0]}x{img.size[1]}, mode={img.mode}")

    # Warn if source is small
    if img.size[0] < 256 or img.size[1] < 256:
        print(f"  WARNING: Source is small ({img.size[0]}x{img.size[1]}). "
              "Quality may be poor when upscaled to 512x512.")

    # Convert to RGBA
    img = img.convert("RGBA")

    # Background replacement
    if not no_replace:
        if replace_color is None:
            detected = detect_background_color(img)
            if detected:
                print(f"  Auto-detected background: RGB({detected[0]}, {detected[1]}, {detected[2]})")
                replace_color = detected
            else:
                print("  Detected transparent background")

        if replace_color or any(
            img.getpixel((x, y))[3] < 128
            for x in [0, img.size[0] - 1]
            for y in [0, img.size[1] - 1]
        ):
            print(f"  Replacing background with: RGB({bg_color[0]}, {bg_color[1]}, {bg_color[2]})")
            img = replace_background(img, replace_color, bg_color, threshold)
    else:
        print("  Skipping background replacement (--no-replace)")
        # Still ensure no transparency at edges for Play Store
        img_with_bg = Image.new("RGBA", img.size, (*bg_color, 255))
        img_with_bg.paste(img, (0, 0), img)
        img = img_with_bg

    # Resize to 512x512
    if img.size != TARGET_SIZE:
        print(f"  Resizing {img.size[0]}x{img.size[1]} -> {TARGET_SIZE[0]}x{TARGET_SIZE[1]}")
        img = img.resize(TARGET_SIZE, Image.LANCZOS)

    # Save as PNG
    os.makedirs(os.path.dirname(output_path) if os.path.dirname(output_path) else ".", exist_ok=True)
    img.save(output_path, "PNG", optimize=True)
    file_size = os.path.getsize(output_path)
    print(f"  Saved: {output_path} ({file_size:,} bytes)")

    # Check file size
    if file_size > MAX_FILE_SIZE:
        print(f"  WARNING: Output exceeds 1MB ({file_size:,} bytes). Attempting further optimization...")
        # Try reducing to RGB if no meaningful alpha
        img_rgb = img.convert("RGB")
        img_rgb.save(output_path, "PNG", optimize=True)
        file_size = os.path.getsize(output_path)
        print(f"  Re-saved as RGB: {output_path} ({file_size:,} bytes)")

        if file_size > MAX_FILE_SIZE:
            print(f"  ERROR: Still exceeds 1MB. Consider simplifying the source image.", file=sys.stderr)
            return False

    # Final verification
    verify = Image.open(output_path)
    print(f"\nVerification:")
    print(f"  Size: {verify.size[0]}x{verify.size[1]}")
    print(f"  Format: {verify.format}")
    print(f"  Mode: {verify.mode}")
    print(f"  File size: {file_size:,} bytes ({'OK' if file_size <= MAX_FILE_SIZE else 'TOO LARGE'})")
    print(f"  Status: {'PASS' if verify.size == TARGET_SIZE and file_size <= MAX_FILE_SIZE else 'FAIL'}")

    return verify.size == TARGET_SIZE and file_size <= MAX_FILE_SIZE


def parse_color(values):
    """Parse R G B color values."""
    if len(values) != 3:
        raise argparse.ArgumentTypeError("Color must be 3 integers: R G B")
    try:
        rgb = tuple(int(v) for v in values)
        for v in rgb:
            if not 0 <= v <= 255:
                raise ValueError
        return rgb
    except ValueError:
        raise argparse.ArgumentTypeError("Color values must be integers 0-255")


def main():
    parser = argparse.ArgumentParser(
        description="Generate Google Play Store compliant 512x512 app icons"
    )
    parser.add_argument("input", help="Source image path")
    parser.add_argument("output", help="Output icon path")
    parser.add_argument("--bg-color", nargs=3, type=int, default=[255, 255, 255],
                        metavar=("R", "G", "B"),
                        help="Background color RGB (default: 255 255 255)")
    parser.add_argument("--replace-color", nargs=3, type=int, default=None,
                        metavar=("R", "G", "B"),
                        help="Color to replace (default: auto-detect)")
    parser.add_argument("--threshold", type=int, default=15,
                        help="Color matching threshold (default: 15)")
    parser.add_argument("--no-replace", action="store_true",
                        help="Skip background replacement (full-bleed artwork)")

    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    bg_color = parse_color(args.bg_color)
    replace_color = parse_color(args.replace_color) if args.replace_color else None

    success = generate_icon(
        args.input, args.output,
        bg_color=bg_color,
        replace_color=replace_color,
        threshold=args.threshold,
        no_replace=args.no_replace
    )

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
