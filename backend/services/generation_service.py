import os

from google import genai
from google.genai import types

# Gemini's cheapest current tier (per-token pricing well below gemini-3.5-flash)
# — single named constant so it's trivially swappable later. gemini-1.5-flash
# (this project's original choice) is now legacy/deprecated; gemini-3.1-flash-lite
# is the current cost-effective equivalent.
_CHAT_MODEL = "gemini-3.1-flash-lite"

_client = None


def _get_client() -> genai.Client:
    global _client
    if _client is None:
        _client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
    return _client


def generate_text(
    prompt: str, *, images: list[bytes] | None = None, json_mode: bool = False
) -> str:
    """Generate text (optionally from a prompt + photos) via Gemini's
    generative model — distinct from embedding_service.py's embed_content,
    which only turns text into a vector and never writes anything."""
    try:
        contents: list = [prompt]
        for image_bytes in images or []:
            contents.append(types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"))

        config = (
            types.GenerateContentConfig(response_mime_type="application/json")
            if json_mode
            else None
        )
        response = _get_client().models.generate_content(
            model=_CHAT_MODEL,
            contents=contents,
            config=config,
        )
        return response.text
    except Exception as e:
        raise RuntimeError(f"Gemini generation failed: {e}") from e
