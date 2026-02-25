#!/usr/bin/env python3
"""Organize and validate app store screenshot captions.

Reads a captions.json file, validates caption lengths against store limits,
and generates a human-readable summary markdown file.
"""

import json
import os
import sys
from datetime import datetime


# Store caption length limits
LIMITS = {
    "play_store": {
        "short": 80,
        "long": 200,
    },
    "app_store": {
        "caption": 70,
        "subtitle": 30,
    },
}


def validate_captions(data):
    """Validate all caption lengths against store limits and required fields."""
    warnings = []
    screenshots = data.get("screenshots", [])
    missing_lang_count = 0

    for i, screenshot in enumerate(screenshots):
        filename = screenshot.get("filename", f"screenshot_{i}")
        captions = screenshot.get("captions", {})

        # Validate detected_language is present
        if not screenshot.get("detected_language"):
            missing_lang_count += 1
            warnings.append(
                f"CRITICAL: {filename}: Missing 'detected_language' field. "
                f"Phase 4 styler cannot create per-language folders without it. "
                f"Add \"detected_language\": \"en\" (or da, de, etc.) to this entry."
            )

        # Validate Play Store captions
        play = captions.get("play_store", {})
        if play:
            short_len = len(play.get("short", ""))
            long_len = len(play.get("long", ""))

            if short_len > LIMITS["play_store"]["short"]:
                warnings.append(
                    f"{filename}: Play Store short caption too long "
                    f"({short_len}/{LIMITS['play_store']['short']} chars)"
                )
            if short_len == 0:
                warnings.append(f"{filename}: Play Store short caption is empty")

            if long_len > LIMITS["play_store"]["long"]:
                warnings.append(
                    f"{filename}: Play Store long caption too long "
                    f"({long_len}/{LIMITS['play_store']['long']} chars)"
                )

        # Validate App Store captions
        apple = captions.get("app_store", {})
        if apple:
            caption_len = len(apple.get("caption", ""))
            subtitle_len = len(apple.get("subtitle", ""))

            if caption_len > LIMITS["app_store"]["caption"]:
                warnings.append(
                    f"{filename}: App Store caption too long "
                    f"({caption_len}/{LIMITS['app_store']['caption']} chars)"
                )
            if caption_len == 0:
                warnings.append(f"{filename}: App Store caption is empty")

            if subtitle_len > LIMITS["app_store"]["subtitle"]:
                warnings.append(
                    f"{filename}: App Store subtitle too long "
                    f"({subtitle_len}/{LIMITS['app_store']['subtitle']} chars)"
                )

    return warnings


def generate_summary(data, warnings):
    """Generate a human-readable markdown summary."""
    app_name = data.get("app_name", "Unknown App")
    platform = data.get("platform", "unknown")
    generated_at = data.get("generated_at", datetime.now().isoformat())
    screenshots = data.get("screenshots", [])

    lines = [
        f"# Screenshot Captions: {app_name}",
        "",
        f"**Platform**: {platform}",
        f"**Generated**: {generated_at}",
        f"**Screenshots**: {len(screenshots)}",
        "",
    ]

    if warnings:
        lines.append("## Warnings")
        lines.append("")
        for w in warnings:
            lines.append(f"- {w}")
        lines.append("")

    lines.append("## Screenshots")
    lines.append("")

    for i, screenshot in enumerate(screenshots, 1):
        filename = screenshot.get("filename", f"screenshot_{i}")
        screen_type = screenshot.get("screen_type", "unknown")
        description = screenshot.get("description", "")
        captions = screenshot.get("captions", {})

        detected_lang = screenshot.get("detected_language", "MISSING")

        lines.append(f"### {i}. {filename}")
        lines.append(f"**Type**: {screen_type} | **Language**: {detected_lang}")
        if description:
            lines.append(f"**Description**: {description}")
        lines.append("")

        play = captions.get("play_store", {})
        if play:
            short = play.get("short", "")
            long = play.get("long", "")
            lines.append("**Play Store**")
            lines.append(f"- Short ({len(short)}/{LIMITS['play_store']['short']}): {short}")
            lines.append(f"- Long ({len(long)}/{LIMITS['play_store']['long']}): {long}")
            lines.append("")

        apple = captions.get("app_store", {})
        if apple:
            caption = apple.get("caption", "")
            subtitle = apple.get("subtitle", "")
            lines.append("**App Store**")
            lines.append(f"- Caption ({len(caption)}/{LIMITS['app_store']['caption']}): {caption}")
            lines.append(f"- Subtitle ({len(subtitle)}/{LIMITS['app_store']['subtitle']}): {subtitle}")
            lines.append("")

        lines.append("---")
        lines.append("")

    return "\n".join(lines)


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <output_dir> <captions.json>", file=sys.stderr)
        sys.exit(1)

    output_dir = sys.argv[1]
    captions_path = sys.argv[2]

    # Read captions
    if not os.path.exists(captions_path):
        print(f"Error: Captions file not found: {captions_path}", file=sys.stderr)
        sys.exit(1)

    with open(captions_path, "r") as f:
        data = json.load(f)

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    # Validate
    warnings = validate_captions(data)

    # Generate summary
    summary = generate_summary(data, warnings)

    # Write outputs
    summary_path = os.path.join(output_dir, "captions_summary.md")
    with open(summary_path, "w") as f:
        f.write(summary)

    # Copy validated captions.json to output
    output_captions_path = os.path.join(output_dir, "captions.json")
    with open(output_captions_path, "w") as f:
        json.dump(data, f, indent=2)

    # Print report
    screenshots = data.get("screenshots", [])
    app_name = data.get("app_name", "Unknown")
    platform = data.get("platform", "unknown")

    # Collect language stats
    lang_counts = {}
    for s in screenshots:
        lang = s.get("detected_language", "MISSING")
        lang_counts[lang] = lang_counts.get(lang, 0) + 1

    print(f"App: {app_name}")
    print(f"Platform: {platform}")
    print(f"Screenshots: {len(screenshots)}")
    print(f"Languages: {', '.join(f'{lang} ({count})' for lang, count in sorted(lang_counts.items()))}")
    print(f"Output: {output_dir}/")
    print(f"  - captions.json")
    print(f"  - captions_summary.md")

    if warnings:
        print(f"\nWarnings ({len(warnings)}):")
        for w in warnings:
            print(f"  - {w}")
    else:
        print("\nAll captions within limits.")

    return 0 if not warnings else 1


if __name__ == "__main__":
    sys.exit(main())
