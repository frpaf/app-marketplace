"""Claude API text generation for screenshot marketing captions."""

import json
import base64
from pathlib import Path

import anthropic

MODEL = "claude-sonnet-4-20250514"

LANG_INSTRUCTIONS = {
    "en": "in English",
    "da": "in Danish (Dansk)",
    "de": "in German (Deutsch)",
    "sv": "in Swedish (Svenska)",
    "no": "in Norwegian (Norsk)",
    "fr": "in French (Français)",
    "es": "in Spanish (Español)",
    "pt": "in Portuguese (Português)",
}

PROMPT_TEMPLATE = """Look at this mobile app screenshot and generate a short, catchy marketing title {lang_instruction} that describes what the user can do on this screen.

Rules:
- Maximum 2 lines of text
- Each line should be max 25 characters
- The text should be suitable for an app store listing
- Focus on the user benefit/action, not technical details
- Use title case

Return ONLY a JSON array of strings, one per line. Example: ["Record Incidents", "Quickly and Efficiently"]"""


def generate_text(image_path: str, lang: str = "en", model: str = MODEL) -> list[str]:
    """
    Send a screenshot to Claude's vision API and get marketing text back.

    Args:
        image_path: Path to the screenshot file.
        lang: Language code (en, da, de, sv, no, fr, es, pt).
        model: Claude model ID to use.

    Returns:
        List of text lines for the marketing caption.

    Raises:
        anthropic.APIError: If the API call fails.
    """
    client = anthropic.Anthropic()

    with open(image_path, "rb") as f:
        image_data = base64.standard_b64encode(f.read()).decode("utf-8")

    ext = Path(image_path).suffix.lower()
    media_type = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
        ".gif": "image/gif",
    }.get(ext, "image/png")

    lang_instruction = LANG_INSTRUCTIONS.get(lang, f"in {lang}")

    response = client.messages.create(
        model=model,
        max_tokens=200,
        messages=[
            {
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
                        "text": PROMPT_TEMPLATE.format(lang_instruction=lang_instruction),
                    },
                ],
            }
        ],
    )

    text = response.content[0].text.strip()
    return _parse_response(text)


def _parse_response(text: str) -> list[str]:
    """Parse the Claude response into a list of text lines."""
    # Try JSON first
    try:
        lines = json.loads(text)
        if isinstance(lines, list):
            return [str(line) for line in lines]
    except json.JSONDecodeError:
        pass

    # Try extracting JSON from markdown code block
    if "```" in text:
        for block in text.split("```"):
            block = block.strip()
            if block.startswith("json"):
                block = block[4:].strip()
            try:
                lines = json.loads(block)
                if isinstance(lines, list):
                    return [str(line) for line in lines]
            except json.JSONDecodeError:
                continue

    # Fallback: split by newlines, strip quotes
    return [
        line.strip().strip('"').strip("'").strip(",").strip('"')
        for line in text.split("\n")
        if line.strip() and line.strip() not in ("[", "]")
    ]


def fallback_text(filename: str) -> list[str]:
    """Generate fallback text from a filename when the API is unavailable."""
    stem = Path(filename).stem
    title = stem.replace("_", " ").replace("-", " ").title()
    return [title]
