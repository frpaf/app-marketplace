"""Config file support for screenshot text overrides."""

import json
from pathlib import Path
from typing import Optional


def load_config(config_path: str) -> dict:
    """Load and validate a screenshot config JSON file."""
    with open(config_path) as f:
        data = json.load(f)

    if not isinstance(data, dict):
        raise ValueError(f"Config must be a JSON object, got {type(data).__name__}")

    return data


def get_defaults(config: dict) -> dict:
    """Extract default settings from config."""
    return config.get("defaults", {})


def get_text_for_screenshot(
    config: dict, filename: str, lang: str
) -> Optional[list[str]]:
    """
    Look up text lines for a specific screenshot and language.

    Args:
        config: Loaded config dict.
        filename: Screenshot filename (e.g., "incident_form.png").
        lang: Language code (e.g., "en", "da").

    Returns:
        List of text lines if found, None otherwise.
    """
    screenshots = config.get("screenshots", {})

    # Try exact filename match
    entry = screenshots.get(filename)
    if entry is None:
        # Try without extension
        stem = Path(filename).stem
        entry = screenshots.get(stem)

    if entry is None:
        return None

    # Entry can be a dict of lang -> lines, or just a list of lines
    if isinstance(entry, dict):
        lines = entry.get(lang)
        if lines is None:
            # Try language prefix (e.g., "en" matches "en-US")
            for key, val in entry.items():
                if key.startswith(lang) or lang.startswith(key):
                    lines = val
                    break
        return lines if isinstance(lines, list) else None
    elif isinstance(entry, list):
        return entry

    return None


def generate_config(
    screenshots: dict[str, dict[str, list[str]]],
    defaults: Optional[dict] = None,
) -> dict:
    """
    Build a config dict from processed screenshots.

    Args:
        screenshots: Mapping of filename -> {lang: [lines]}.
        defaults: Optional default settings.

    Returns:
        Config dict ready to serialize as JSON.
    """
    config = {}
    if defaults:
        config["defaults"] = defaults
    config["screenshots"] = screenshots
    return config


def get_screenshot_order(config: dict) -> list[str]:
    """
    Return screenshot filenames in config-defined order.

    The order comes from the insertion order of the "screenshots" dict keys.
    This lets users control store listing order by arranging the config file.

    Returns:
        List of screenshot filenames/stems in order.
    """
    return list(config.get("screenshots", {}).keys())


def save_config(config: dict, output_path: str) -> None:
    """Write config to a JSON file with readable formatting."""
    with open(output_path, "w") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
    print(f"Config saved to {output_path}")
