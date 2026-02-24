"""CLI interface for Screenshot Styler."""

import os
import sys
import argparse
from pathlib import Path

from .compositor import create_styled_screenshot
from .textgen import generate_text, fallback_text
from .config import (
    load_config,
    get_text_for_screenshot,
    get_defaults,
    get_screenshot_order,
    generate_config,
    save_config,
)

# Fastlane locale mapping: lang code -> Fastlane directory name
# Play Store (supply) and App Store (deliver) use different conventions.
# This covers the common ones; unmapped codes are used as-is.
FASTLANE_LOCALES = {
    "en": "en-US",
    "da": "da",
    "de": "de-DE",
    "sv": "sv-SE",
    "no": "no-NO",
    "fr": "fr-FR",
    "es": "es-ES",
    "pt": "pt-BR",
    "nl": "nl-NL",
    "it": "it-IT",
    "ja": "ja-JP",
    "ko": "ko-KR",
    "zh": "zh-Hans",
}


def collect_images(input_path: Path) -> list[Path]:
    """Collect image files from a path (file or directory)."""
    valid_extensions = {".png", ".jpg", ".jpeg", ".webp"}

    if input_path.is_file():
        if input_path.suffix.lower() in valid_extensions:
            return [input_path]
        print(f"Error: {input_path} is not a supported image format ({', '.join(valid_extensions)})")
        sys.exit(1)

    if input_path.is_dir():
        files = sorted(
            f for f in input_path.iterdir()
            if f.suffix.lower() in valid_extensions
        )
        return files

    print(f"Error: {input_path} does not exist")
    sys.exit(1)


def order_files(files: list[Path], config: dict | None) -> list[Path]:
    """
    Order files according to config screenshot order, falling back to alphabetical.

    Files present in config come first (in config order), followed by any
    remaining files in alphabetical order.
    """
    if not config:
        return files

    config_order = get_screenshot_order(config)
    if not config_order:
        return files

    # Build a lookup: stem or full name -> Path
    file_map = {}
    for f in files:
        file_map[f.name] = f
        file_map[f.stem] = f

    ordered = []
    seen = set()
    for key in config_order:
        match = file_map.get(key)
        if match and match not in seen:
            ordered.append(match)
            seen.add(match)

    # Append remaining files not in config
    for f in files:
        if f not in seen:
            ordered.append(f)

    return ordered


def resolve_text(
    filepath: Path,
    lang: str,
    custom_text: str | None,
    config: dict | None,
) -> list[str]:
    """Determine text lines for a screenshot, checking overrides first."""
    # 1. CLI text override
    if custom_text:
        return [line.strip() for line in custom_text.split("\\n")]

    # 2. Config file lookup
    if config:
        lines = get_text_for_screenshot(config, filepath.name, lang)
        if lines:
            return lines

    # 3. Claude API generation
    print(f"  Generating text ({lang})...")
    try:
        lines = generate_text(str(filepath), lang)
        return lines
    except Exception as e:
        print(f"  API error: {e}")
        print(f"  Using filename as fallback")
        return fallback_text(filepath.name)


def parse_bg_color(bg_color_str: str | None) -> tuple:
    """Parse a R,G,B string into a tuple, or return the default."""
    if not bg_color_str:
        return (55, 71, 90)
    try:
        parts = [int(x.strip()) for x in bg_color_str.split(",")]
        if len(parts) == 3:
            return tuple(parts)
    except ValueError:
        pass
    print(f"Error: --bg-color must be integers R,G,B (got {bg_color_str})")
    sys.exit(1)


def parse_langs(langs_str: str | None, single_lang: str) -> list[str]:
    """Parse --langs 'en,da' or fall back to single --lang value."""
    if langs_str:
        return [l.strip() for l in langs_str.split(",") if l.strip()]
    return [single_lang]


def fastlane_locale(lang: str) -> str:
    """Map a language code to its Fastlane metadata directory name."""
    return FASTLANE_LOCALES.get(lang, lang)


# ─── Processing Modes ───────────────────────────────────────────────────────

def process(args: argparse.Namespace) -> None:
    """Main processing logic — dispatches to the right mode."""
    input_path = Path(args.input)

    # Load config
    config = None
    font_size = 52
    bg_color = parse_bg_color(args.bg_color)

    if args.config:
        config_path = Path(args.config)
        if not config_path.exists():
            print(f"Error: Config file not found: {args.config}")
            sys.exit(1)
        config = load_config(str(config_path))
        defaults = get_defaults(config)
        if "bg_color" in defaults and not args.bg_color:
            bg_color = tuple(defaults["bg_color"])
        if "font_size" in defaults:
            font_size = defaults["font_size"]

    files = collect_images(input_path)
    if not files:
        print(f"No image files found in {input_path}")
        sys.exit(1)

    # Order files by config, then alphabetical
    files = order_files(files, config)

    # Handle --generate-config mode
    if args.generate_config:
        langs = parse_langs(args.langs, args.lang)
        _do_generate_config(files, langs, args.generate_config)
        return

    # Handle --dry-run
    if args.dry_run:
        if args.fastlane:
            langs = parse_langs(args.langs, args.lang)
            _do_fastlane_dry_run(files, langs, args.fastlane, config, args.text)
        else:
            _do_dry_run(files, args, config)
        return

    # Fastlane mode vs regular mode
    if args.fastlane:
        langs = parse_langs(args.langs, args.lang)
        _do_fastlane(files, langs, args.fastlane, config, args.text, bg_color, font_size)
    else:
        _do_regular(files, args, config, bg_color, font_size)


def _do_regular(
    files: list[Path],
    args: argparse.Namespace,
    config: dict | None,
    bg_color: tuple,
    font_size: int,
) -> None:
    """Standard mode: process screenshots into output directory."""
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"\nProcessing {len(files)} screenshot(s)...\n")

    for i, filepath in enumerate(files, 1):
        print(f"[{i}/{len(files)}] {filepath.name}")

        lines = resolve_text(filepath, args.lang, args.text, config)
        print(f"  Text: {' / '.join(lines)}")

        output_name = f"{filepath.stem}_styled.png"
        output_path = str(output_dir / output_name)

        create_styled_screenshot(
            str(filepath), output_path, lines,
            bg_color=bg_color, font_size=font_size,
        )

    print(f"\nDone! {len(files)} styled screenshot(s) saved to {output_dir}/\n")


def _do_fastlane(
    files: list[Path],
    langs: list[str],
    fastlane_path: str,
    config: dict | None,
    custom_text: str | None,
    bg_color: tuple,
    font_size: int,
) -> None:
    """
    Fastlane mode: output into Fastlane metadata directory structure.

    Creates:
        <fastlane_path>/<locale>/images/phoneScreenshots/1_name_styled.png
    """
    metadata_dir = Path(fastlane_path)
    total = len(files) * len(langs)
    count = 0

    print(f"\nFastlane mode: {len(files)} screenshot(s) x {len(langs)} language(s) = {total} image(s)\n")

    for lang in langs:
        locale = fastlane_locale(lang)
        screenshots_dir = metadata_dir / locale / "images" / "phoneScreenshots"
        screenshots_dir.mkdir(parents=True, exist_ok=True)

        print(f"--- {locale} ---")

        for i, filepath in enumerate(files, 1):
            count += 1
            print(f"[{count}/{total}] {filepath.name} ({locale})")

            lines = resolve_text(filepath, lang, custom_text, config)
            print(f"  Text: {' / '.join(lines)}")

            # Numbered prefix for store ordering
            output_name = f"{i}_{filepath.stem}_styled.png"
            output_path = str(screenshots_dir / output_name)

            create_styled_screenshot(
                str(filepath), output_path, lines,
                bg_color=bg_color, font_size=font_size,
            )

        print()

    print(f"Done! {count} styled screenshot(s) saved to {metadata_dir}/\n")


def _do_fastlane_dry_run(
    files: list[Path],
    langs: list[str],
    fastlane_path: str,
    config: dict | None,
    custom_text: str | None,
) -> None:
    """Preview Fastlane output structure without generating images."""
    metadata_dir = Path(fastlane_path)
    total = len(files) * len(langs)

    print(f"\n[DRY RUN] Fastlane mode: {len(files)} screenshot(s) x {len(langs)} language(s) = {total} image(s)\n")

    for lang in langs:
        locale = fastlane_locale(lang)
        screenshots_dir = metadata_dir / locale / "images" / "phoneScreenshots"

        print(f"--- {locale} ---")

        for i, filepath in enumerate(files, 1):
            lines = None
            source = "API"
            if custom_text:
                lines = [line.strip() for line in custom_text.split("\\n")]
                source = "CLI --text"
            elif config:
                lines = get_text_for_screenshot(config, filepath.name, lang)
                if lines:
                    source = "config"

            text_display = " / ".join(lines) if lines else "(would generate via Claude API)"
            output_name = f"{i}_{filepath.stem}_styled.png"
            print(f"  [{i}] {filepath.name}")
            print(f"      Text: {text_display} [{source}]")
            print(f"      Output: {screenshots_dir / output_name}")

        print()


def _do_generate_config(files: list[Path], langs: list[str], output_path: str) -> None:
    """Generate a config file from AI-analyzed screenshots."""
    print(f"\nGenerating config for {len(files)} screenshot(s) in {langs}...\n")

    screenshots = {}
    for i, filepath in enumerate(files, 1):
        print(f"[{i}/{len(files)}] {filepath.name}")
        entry = {}
        for lang in langs:
            print(f"  Generating text ({lang})...")
            try:
                lines = generate_text(str(filepath), lang)
            except Exception as e:
                print(f"  API error: {e}")
                lines = fallback_text(filepath.name)
            print(f"  Text ({lang}): {' / '.join(lines)}")
            entry[lang] = lines
        screenshots[filepath.name] = entry

    config = generate_config(screenshots, defaults={"bg_color": [55, 71, 90], "font_size": 52})
    save_config(config, output_path)
    print(f"\nConfig generated! Edit {output_path} to adjust text, then use --config to apply.\n")


def _do_dry_run(
    files: list[Path],
    args: argparse.Namespace,
    config: dict | None,
) -> None:
    """Preview what would be processed without generating images."""
    print(f"\n[DRY RUN] Would process {len(files)} screenshot(s):\n")
    for i, filepath in enumerate(files, 1):
        lines = None
        source = "API"
        if args.text:
            lines = [line.strip() for line in args.text.split("\\n")]
            source = "CLI --text"
        elif config:
            lines = get_text_for_screenshot(config, filepath.name, args.lang)
            if lines:
                source = "config"

        text_display = " / ".join(lines) if lines else "(would generate via Claude API)"
        output_name = f"{filepath.stem}_styled.png"
        print(f"  [{i}] {filepath.name}")
        print(f"      Text: {text_display} [{source}]")
        print(f"      Output: {Path(args.output) / output_name}")
    print()


# ─── Argument Parser ────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    """Build the argument parser."""
    parser = argparse.ArgumentParser(
        prog="screenshot-styler",
        description="Create app store-ready screenshots with phone frames and auto-generated text",
    )
    parser.add_argument(
        "--input", "-i", required=True,
        help="Input screenshot file or folder",
    )
    parser.add_argument(
        "--output", "-o", default=None,
        help="Output directory for styled screenshots (used in regular mode)",
    )
    parser.add_argument(
        "--lang", "-l", default="en",
        help="Language for generated text (en, da, de, sv, no, fr, es, pt). Default: en",
    )
    parser.add_argument(
        "--langs", default=None,
        help="Comma-separated languages for multi-language processing (e.g., 'en,da,de'). "
             "Used with --fastlane or --generate-config.",
    )
    parser.add_argument(
        "--text", "-t", default=None,
        help="Custom text override (use \\n for line breaks). Overrides AI generation.",
    )
    parser.add_argument(
        "--bg-color", default=None,
        help="Background color as R,G,B (e.g., '55,71,90')",
    )
    parser.add_argument(
        "--config", "-c", default=None,
        help="Path to JSON config file with per-screenshot text overrides",
    )
    parser.add_argument(
        "--fastlane", default=None, metavar="METADATA_PATH",
        help="Output into Fastlane metadata directory structure. "
             "Path should point to the fastlane/metadata directory.",
    )
    parser.add_argument(
        "--generate-config", default=None, metavar="OUTPUT_JSON",
        help="Generate a config file from AI-analyzed screenshots (provide output JSON path)",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Preview what would be processed without generating images",
    )
    return parser


def main() -> None:
    """CLI entry point."""
    parser = build_parser()
    args = parser.parse_args()

    # Validate: need either --output or --fastlane
    if not args.fastlane and not args.output and not args.generate_config:
        parser.error("Either --output (-o) or --fastlane is required")

    # Default --output for non-fastlane mode
    if not args.fastlane and not args.output and args.generate_config:
        args.output = "."  # generate-config doesn't need output dir, but process() checks it

    process(args)
