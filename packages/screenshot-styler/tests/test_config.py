"""Tests for config file support."""

import json
import tempfile
from pathlib import Path

import pytest

from screenshot_styler.config import (
    load_config,
    get_text_for_screenshot,
    get_defaults,
    generate_config,
    save_config,
)


SAMPLE_CONFIG = {
    "defaults": {
        "bg_color": [55, 71, 90],
        "font_size": 52,
    },
    "screenshots": {
        "incident_form.png": {
            "en": ["Record Incidents", "Quickly and Efficiently"],
            "da": ["Registrer en hændelse", "på få minutter"],
        },
        "documentation.png": {
            "en": ["Easy Access to", "Documents and Guides"],
        },
        "simple.png": ["Just One Line"],
    },
}


@pytest.fixture
def config_file(tmp_path):
    """Write sample config to a temp file."""
    path = tmp_path / "config.json"
    with open(path, "w") as f:
        json.dump(SAMPLE_CONFIG, f)
    return str(path)


class TestLoadConfig:
    def test_loads_valid_config(self, config_file):
        config = load_config(config_file)
        assert "screenshots" in config
        assert "defaults" in config

    def test_rejects_non_object(self, tmp_path):
        path = tmp_path / "bad.json"
        with open(path, "w") as f:
            json.dump([1, 2, 3], f)
        with pytest.raises(ValueError, match="JSON object"):
            load_config(str(path))

    def test_rejects_missing_file(self):
        with pytest.raises(FileNotFoundError):
            load_config("/nonexistent/path.json")


class TestGetDefaults:
    def test_returns_defaults(self):
        defaults = get_defaults(SAMPLE_CONFIG)
        assert defaults["bg_color"] == [55, 71, 90]
        assert defaults["font_size"] == 52

    def test_empty_defaults(self):
        assert get_defaults({}) == {}


class TestGetTextForScreenshot:
    def test_exact_match(self):
        lines = get_text_for_screenshot(SAMPLE_CONFIG, "incident_form.png", "en")
        assert lines == ["Record Incidents", "Quickly and Efficiently"]

    def test_danish(self):
        lines = get_text_for_screenshot(SAMPLE_CONFIG, "incident_form.png", "da")
        assert lines == ["Registrer en hændelse", "på få minutter"]

    def test_missing_language(self):
        lines = get_text_for_screenshot(SAMPLE_CONFIG, "incident_form.png", "fr")
        assert lines is None

    def test_missing_screenshot(self):
        lines = get_text_for_screenshot(SAMPLE_CONFIG, "nonexistent.png", "en")
        assert lines is None

    def test_stem_match(self):
        """Match by filename stem (no extension)."""
        lines = get_text_for_screenshot(SAMPLE_CONFIG, "incident_form.jpg", "en")
        # Should match "incident_form.png" entry via stem
        # Actually this won't match because we look up by exact name first, then stem
        # Let's test with a config that uses stems
        config = {"screenshots": {"incident_form": {"en": ["Test"]}}}
        lines = get_text_for_screenshot(config, "incident_form.png", "en")
        assert lines == ["Test"]

    def test_plain_list_entry(self):
        """Config entry can be a plain list (no language dict)."""
        lines = get_text_for_screenshot(SAMPLE_CONFIG, "simple.png", "en")
        assert lines == ["Just One Line"]

    def test_language_prefix_match(self):
        """'en' should match 'en-US' config keys."""
        config = {
            "screenshots": {
                "test.png": {"en-US": ["US English Text"]},
            }
        }
        lines = get_text_for_screenshot(config, "test.png", "en")
        assert lines == ["US English Text"]


class TestGenerateConfig:
    def test_builds_config(self):
        screenshots = {
            "screen1.png": {"en": ["Hello World"]},
            "screen2.png": {"en": ["Goodbye"]},
        }
        config = generate_config(screenshots)
        assert "screenshots" in config
        assert len(config["screenshots"]) == 2

    def test_includes_defaults(self):
        config = generate_config({}, defaults={"bg_color": [0, 0, 0]})
        assert config["defaults"]["bg_color"] == [0, 0, 0]


class TestSaveConfig:
    def test_saves_json(self, tmp_path):
        config = {"screenshots": {"test.png": {"en": ["Hello"]}}}
        path = str(tmp_path / "out.json")
        save_config(config, path)
        with open(path) as f:
            loaded = json.load(f)
        assert loaded == config

    def test_preserves_unicode(self, tmp_path):
        config = {"screenshots": {"test.png": {"da": ["Hændelse"]}}}
        path = str(tmp_path / "out.json")
        save_config(config, path)
        with open(path) as f:
            content = f.read()
        assert "Hændelse" in content  # Not escaped
