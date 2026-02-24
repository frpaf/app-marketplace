"""Tests for text generation (parsing only — no API calls)."""

import pytest

from screenshot_styler.textgen import _parse_response, fallback_text


class TestParseResponse:
    def test_valid_json_array(self):
        result = _parse_response('["Hello World", "Second Line"]')
        assert result == ["Hello World", "Second Line"]

    def test_single_element(self):
        result = _parse_response('["Just One"]')
        assert result == ["Just One"]

    def test_json_in_code_block(self):
        text = '```json\n["Inside Block", "Here"]\n```'
        result = _parse_response(text)
        assert result == ["Inside Block", "Here"]

    def test_plain_text_fallback(self):
        text = '"Line One"\n"Line Two"'
        result = _parse_response(text)
        assert "Line One" in result
        assert "Line Two" in result

    def test_empty_lines_filtered(self):
        text = '\n"Hello"\n\n"World"\n'
        result = _parse_response(text)
        assert len(result) == 2

    def test_brackets_filtered(self):
        text = '[\n"Hello",\n"World"\n]'
        result = _parse_response(text)
        assert result == ["Hello", "World"]

    def test_integer_elements(self):
        """JSON array with non-string elements should be converted."""
        result = _parse_response("[1, 2, 3]")
        assert result == ["1", "2", "3"]


class TestFallbackText:
    def test_underscores_to_spaces(self):
        result = fallback_text("incident_form.png")
        assert result == ["Incident Form"]

    def test_hyphens_to_spaces(self):
        result = fallback_text("my-cool-screen.png")
        assert result == ["My Cool Screen"]

    def test_title_case(self):
        result = fallback_text("hello_world.png")
        assert result == ["Hello World"]
