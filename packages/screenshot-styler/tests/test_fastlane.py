"""Tests for Fastlane integration (Phase 2)."""

import json
import subprocess
import sys
from pathlib import Path

import pytest
from PIL import Image

from screenshot_styler.cli import (
    order_files,
    fastlane_locale,
    parse_langs,
    FASTLANE_LOCALES,
)


# ─── Locale Mapping ────────────────────────────────────────────────────────

class TestFastlaneLocale:
    def test_english(self):
        assert fastlane_locale("en") == "en-US"

    def test_danish(self):
        assert fastlane_locale("da") == "da"

    def test_german(self):
        assert fastlane_locale("de") == "de-DE"

    def test_unknown_passthrough(self):
        assert fastlane_locale("xx") == "xx"


# ─── Language Parsing ───────────────────────────────────────────────────────

class TestParseLangs:
    def test_comma_separated(self):
        assert parse_langs("en,da,de", "en") == ["en", "da", "de"]

    def test_single_lang_fallback(self):
        assert parse_langs(None, "da") == ["da"]

    def test_strips_whitespace(self):
        assert parse_langs(" en , da ", "en") == ["en", "da"]

    def test_empty_entries_filtered(self):
        assert parse_langs("en,,da,", "en") == ["en", "da"]


# ─── File Ordering ──────────────────────────────────────────────────────────

class TestOrderFiles:
    def test_config_order(self, tmp_path):
        """Files are ordered by config key order."""
        # Create files
        (tmp_path / "c.png").touch()
        (tmp_path / "a.png").touch()
        (tmp_path / "b.png").touch()
        files = sorted(tmp_path.glob("*.png"))

        config = {"screenshots": {"b.png": {}, "a.png": {}, "c.png": {}}}
        ordered = order_files(files, config)
        assert [f.name for f in ordered] == ["b.png", "a.png", "c.png"]

    def test_no_config(self, tmp_path):
        """Without config, original order preserved."""
        (tmp_path / "c.png").touch()
        (tmp_path / "a.png").touch()
        files = sorted(tmp_path.glob("*.png"))
        ordered = order_files(files, None)
        assert ordered == files

    def test_extra_files_appended(self, tmp_path):
        """Files not in config come after config-ordered files."""
        (tmp_path / "a.png").touch()
        (tmp_path / "b.png").touch()
        (tmp_path / "extra.png").touch()
        files = sorted(tmp_path.glob("*.png"))

        config = {"screenshots": {"b.png": {}}}
        ordered = order_files(files, config)
        assert ordered[0].name == "b.png"
        assert len(ordered) == 3

    def test_stem_matching(self, tmp_path):
        """Config keys without extension match files by stem."""
        (tmp_path / "incident_form.png").touch()
        files = list(tmp_path.glob("*.png"))

        config = {"screenshots": {"incident_form": {}}}
        ordered = order_files(files, config)
        assert ordered[0].name == "incident_form.png"


# ─── Fastlane CLI Integration ──────────────────────────────────────────────

@pytest.fixture
def sample_images(tmp_path):
    """Create sample input screenshots."""
    input_dir = tmp_path / "raw"
    input_dir.mkdir()
    for name in ["incident_form.png", "documentation.png", "attachments.png"]:
        img = Image.new("RGB", (1080, 2340), (70, 130, 200))
        img.save(str(input_dir / name))
    return input_dir


@pytest.fixture
def sample_config(tmp_path):
    """Create a config file with text for multiple languages."""
    config = {
        "defaults": {"bg_color": [55, 71, 90], "font_size": 52},
        "screenshots": {
            "incident_form.png": {
                "en": ["Record Incidents", "Quickly and Efficiently"],
                "da": ["Registrer Hændelser", "Hurtigt og Effektivt"],
            },
            "documentation.png": {
                "en": ["Easy Access to", "Documents and Guides"],
                "da": ["Nem Adgang til", "Dokumenter og Vejledninger"],
            },
            "attachments.png": {
                "en": ["Attach Relevant Pictures"],
                "da": ["Vedhæft Billeder"],
            },
        },
    }
    path = tmp_path / "config.json"
    with open(path, "w") as f:
        json.dump(config, f)
    return str(path)


class TestFastlaneCLI:
    def _run(self, *extra_args) -> subprocess.CompletedProcess:
        """Run the CLI as a subprocess."""
        cmd = [sys.executable, "-m", "screenshot_styler"] + list(extra_args)
        return subprocess.run(cmd, capture_output=True, text=True, timeout=30)

    def test_fastlane_directory_structure(self, sample_images, sample_config, tmp_path):
        """--fastlane creates the expected directory layout."""
        metadata = tmp_path / "metadata"
        result = self._run(
            "-i", str(sample_images),
            "--fastlane", str(metadata),
            "--config", sample_config,
            "--langs", "en,da",
        )
        assert result.returncode == 0, result.stderr

        # Check English directory
        en_dir = metadata / "en-US" / "images" / "phoneScreenshots"
        assert en_dir.exists()
        en_files = sorted(en_dir.glob("*.png"))
        assert len(en_files) == 3

        # Check Danish directory
        da_dir = metadata / "da" / "images" / "phoneScreenshots"
        assert da_dir.exists()
        da_files = sorted(da_dir.glob("*.png"))
        assert len(da_files) == 3

    def test_numbered_prefixes(self, sample_images, sample_config, tmp_path):
        """Output files have numbered prefixes matching config order."""
        metadata = tmp_path / "metadata"
        result = self._run(
            "-i", str(sample_images),
            "--fastlane", str(metadata),
            "--config", sample_config,
            "--langs", "en",
        )
        assert result.returncode == 0, result.stderr

        en_dir = metadata / "en-US" / "images" / "phoneScreenshots"
        files = sorted(en_dir.glob("*.png"))
        names = [f.name for f in files]

        # Files should start with 1_, 2_, 3_
        assert names[0].startswith("1_")
        assert names[1].startswith("2_")
        assert names[2].startswith("3_")

    def test_output_image_valid(self, sample_images, sample_config, tmp_path):
        """Generated Fastlane images are valid 1080x1920 PNGs."""
        metadata = tmp_path / "metadata"
        self._run(
            "-i", str(sample_images),
            "--fastlane", str(metadata),
            "--config", sample_config,
            "--langs", "en",
        )

        en_dir = metadata / "en-US" / "images" / "phoneScreenshots"
        for png_file in en_dir.glob("*.png"):
            img = Image.open(str(png_file))
            assert img.size == (1080, 1920)
            assert img.format == "PNG"

    def test_fastlane_dry_run(self, sample_images, sample_config, tmp_path):
        """--dry-run with --fastlane shows plan without creating files."""
        metadata = tmp_path / "metadata"
        result = self._run(
            "-i", str(sample_images),
            "--fastlane", str(metadata),
            "--config", sample_config,
            "--langs", "en,da",
            "--dry-run",
        )
        assert result.returncode == 0, result.stderr
        assert "DRY RUN" in result.stdout
        assert "en-US" in result.stdout
        assert "da" in result.stdout
        # No files should be created
        assert not metadata.exists()

    def test_single_lang_with_fastlane(self, sample_images, sample_config, tmp_path):
        """--fastlane with --lang (not --langs) processes one language."""
        metadata = tmp_path / "metadata"
        result = self._run(
            "-i", str(sample_images),
            "--fastlane", str(metadata),
            "--config", sample_config,
            "--lang", "da",
        )
        assert result.returncode == 0, result.stderr
        assert (metadata / "da" / "images" / "phoneScreenshots").exists()
        assert not (metadata / "en-US" / "images" / "phoneScreenshots").exists()

    def test_requires_output_or_fastlane(self):
        """CLI errors if neither --output nor --fastlane is given."""
        result = self._run("-i", "/tmp")
        assert result.returncode != 0
