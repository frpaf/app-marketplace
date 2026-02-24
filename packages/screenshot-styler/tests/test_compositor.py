"""Tests for the image composition engine."""

import os
import tempfile
from pathlib import Path

import pytest
from PIL import Image

from screenshot_styler.compositor import (
    create_styled_screenshot,
    rounded_rect,
    get_font,
    CANVAS_WIDTH,
    CANVAS_HEIGHT,
)


@pytest.fixture
def sample_screenshot(tmp_path):
    """Create a simple test screenshot."""
    img = Image.new("RGB", (1080, 2340), color=(100, 150, 200))
    path = tmp_path / "test_screen.png"
    img.save(str(path))
    return str(path)


@pytest.fixture
def landscape_screenshot(tmp_path):
    """Create a landscape test screenshot."""
    img = Image.new("RGB", (1920, 1080), color=(200, 100, 100))
    path = tmp_path / "test_landscape.png"
    img.save(str(path))
    return str(path)


@pytest.fixture
def small_screenshot(tmp_path):
    """Create a small/low-res screenshot."""
    img = Image.new("RGB", (320, 480), color=(100, 200, 100))
    path = tmp_path / "test_small.png"
    img.save(str(path))
    return str(path)


@pytest.fixture
def output_dir(tmp_path):
    return tmp_path / "output"


class TestCreateStyledScreenshot:
    def test_output_dimensions(self, sample_screenshot, output_dir):
        """Output must be exactly 1080x1920."""
        out = str(output_dir / "styled.png")
        create_styled_screenshot(sample_screenshot, out, ["Test Title"])
        img = Image.open(out)
        assert img.size == (CANVAS_WIDTH, CANVAS_HEIGHT)

    def test_output_is_png(self, sample_screenshot, output_dir):
        """Output must be PNG format."""
        out = str(output_dir / "styled.png")
        create_styled_screenshot(sample_screenshot, out, ["Test"])
        img = Image.open(out)
        assert img.format == "PNG"

    def test_output_under_8mb(self, sample_screenshot, output_dir):
        """Output must be under 8MB (store requirement)."""
        out = str(output_dir / "styled.png")
        create_styled_screenshot(sample_screenshot, out, ["Test Title"])
        size_mb = os.path.getsize(out) / (1024 * 1024)
        assert size_mb < 8

    def test_single_line_text(self, sample_screenshot, output_dir):
        """Works with a single line of text."""
        out = str(output_dir / "styled.png")
        result = create_styled_screenshot(sample_screenshot, out, ["One Line"])
        assert os.path.exists(result)

    def test_two_line_text(self, sample_screenshot, output_dir):
        """Works with two lines of text."""
        out = str(output_dir / "styled.png")
        result = create_styled_screenshot(sample_screenshot, out, ["Line One", "Line Two"])
        assert os.path.exists(result)

    def test_three_line_text(self, sample_screenshot, output_dir):
        """Works with three lines of text."""
        out = str(output_dir / "styled.png")
        result = create_styled_screenshot(
            sample_screenshot, out, ["Line One", "Line Two", "Line Three"]
        )
        assert os.path.exists(result)

    def test_landscape_screenshot(self, landscape_screenshot, output_dir):
        """Handles landscape screenshots without crashing."""
        out = str(output_dir / "styled.png")
        result = create_styled_screenshot(landscape_screenshot, out, ["Landscape Mode"])
        assert os.path.exists(result)
        img = Image.open(result)
        assert img.size == (CANVAS_WIDTH, CANVAS_HEIGHT)

    def test_small_screenshot(self, small_screenshot, output_dir):
        """Handles low-res screenshots (scaled up)."""
        out = str(output_dir / "styled.png")
        result = create_styled_screenshot(small_screenshot, out, ["Small Screen"])
        assert os.path.exists(result)

    def test_custom_bg_color(self, sample_screenshot, output_dir):
        """Accepts custom background color."""
        out = str(output_dir / "styled.png")
        create_styled_screenshot(
            sample_screenshot, out, ["Custom BG"], bg_color=(255, 0, 0)
        )
        img = Image.open(out)
        # Check top-left pixel is red-ish (background)
        pixel = img.getpixel((5, 5))
        assert pixel[0] > 200  # Red channel should be high

    def test_custom_font_size(self, sample_screenshot, output_dir):
        """Accepts custom font size."""
        out = str(output_dir / "styled.png")
        result = create_styled_screenshot(
            sample_screenshot, out, ["Big Text"], font_size=72
        )
        assert os.path.exists(result)

    def test_creates_output_directory(self, sample_screenshot, tmp_path):
        """Creates output directory if it doesn't exist."""
        nested = tmp_path / "a" / "b" / "c"
        out = str(nested / "styled.png")
        result = create_styled_screenshot(sample_screenshot, out, ["Test"])
        assert os.path.exists(result)

    def test_unicode_text(self, sample_screenshot, output_dir):
        """Handles Danish characters (and other Unicode)."""
        out = str(output_dir / "styled.png")
        result = create_styled_screenshot(
            sample_screenshot, out, ["Registrer Hændelse", "på få minutter"]
        )
        assert os.path.exists(result)

    def test_jpeg_input(self, tmp_path, output_dir):
        """Accepts JPEG input."""
        img = Image.new("RGB", (1080, 1920), color=(50, 50, 50))
        jpeg_path = tmp_path / "test.jpg"
        img.save(str(jpeg_path), "JPEG")
        out = str(output_dir / "styled.png")
        result = create_styled_screenshot(str(jpeg_path), out, ["JPEG Test"])
        assert os.path.exists(result)


class TestGetFont:
    def test_returns_font(self):
        """Should return a usable font object."""
        font = get_font()
        assert font is not None

    def test_custom_size(self):
        """Should accept custom size."""
        font = get_font(72)
        assert font is not None


class TestRoundedRect:
    def test_draws_without_error(self):
        """Rounded rect drawing should not raise."""
        img = Image.new("RGB", (200, 200), (0, 0, 0))
        draw = Image.new("RGB", (200, 200), (0, 0, 0))
        from PIL import ImageDraw
        d = ImageDraw.Draw(img)
        rounded_rect(d, (10, 10, 190, 190), 20, (255, 255, 255))
        # Check that some white pixels exist
        pixels = list(img.getdata())
        white_count = sum(1 for p in pixels if p == (255, 255, 255))
        assert white_count > 0
