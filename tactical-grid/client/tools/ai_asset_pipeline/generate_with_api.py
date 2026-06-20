"""
Example AI image generation pipeline.
Fill in your API_KEY and API_URL, then run this script to generate real images
from the prompts created by generate_prompts.py.

By default it expects an OpenAI-compatible image generation endpoint:
  POST /images/generations
  { "prompt": "...", "n": 1, "size": "1024x1024", "response_format": "b64_json" }

For Stable Diffusion / Midjourney / 可灵 / 即梦, replace call_api() with their SDK.
"""
import base64
import json
import os
import time
from pathlib import Path

import requests

ROOT = Path(__file__).parent
PROMPTS_DIR = ROOT / "prompts"
OUT_DIR = Path(__file__).parent.parent.parent / "assets"

# TODO: fill in your own credentials
API_URL = os.environ.get("AI_IMAGE_API_URL", "https://api.openai.com/v1/images/generations")
API_KEY = os.environ.get("AI_IMAGE_API_KEY", "")

# Map prompt category -> output asset folder and image size
CATEGORY_CONFIG = {
    "portraits/player":     ("characters/generated", "portrait_{id}.png", "1024x1024"),
    "portraits/enemy":      ("characters/generated", "portrait_{id}.png", "1024x1024"),
    "portraits/boss":       ("characters/generated", "portrait_{id}.png", "1024x1024"),
    "units/player":         ("units", "player_{id}.png", "1024x1024"),
    "units/enemy":          ("units", "enemy_{id}.png", "1024x1024"),
    "units/boss":           ("units", "boss_{id}.png", "1024x1024"),
    "weapons":              ("weapons", "{id}.png", "1024x1024"),
    "items":                ("items", "{id}.png", "1024x1024"),
    "skills":               ("skills", "{id}.png", "1024x1024"),
    "objects":              ("objects", "{id}.png", "1024x1024"),
    "effects":              ("effects/generated", "{id}.png", "1024x1024"),
    "tiles":                ("tiles/generated", "theme_{id}.png", "1792x1024"),
}

def call_api(prompt: str, size: str) -> bytes:
    if not API_KEY:
        raise RuntimeError("Please set AI_IMAGE_API_KEY environment variable.")
    headers = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}
    payload = {"prompt": prompt, "n": 1, "size": size, "response_format": "b64_json"}
    resp = requests.post(API_URL, headers=headers, json=payload, timeout=120)
    resp.raise_for_status()
    data = resp.json()
    b64 = data["data"][0]["b64_json"]
    return base64.b64decode(b64)

def postprocess(img_bytes: bytes, out_path: Path, is_tile: bool):
    """Optional: resize, remove background, slice atlas. Placeholder implementation."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(img_bytes)
    print(f"  saved {out_path}")

def generate_category(category: str):
    if category not in CATEGORY_CONFIG:
        print(f"Unknown category: {category}")
        return
    folder, filename_template, size = CATEGORY_CONFIG[category]
    prompt_dir = PROMPTS_DIR / category
    if not prompt_dir.exists():
        print(f"No prompts found for {category}")
        return

    print(f"Generating {category}...")
    for en_file in sorted(prompt_dir.glob("*_en.txt")):
        asset_id = en_file.stem.replace("_en", "")
        out_name = filename_template.format(id=asset_id)
        out_path = OUT_DIR / folder / out_name
        if out_path.exists():
            print(f"  skip existing: {out_path}")
            continue
        prompt = en_file.read_text("utf-8")
        try:
            img_bytes = call_api(prompt, size)
            postprocess(img_bytes, out_path, is_tile=(category == "tiles"))
            time.sleep(0.5)
        except Exception as e:
            print(f"  FAILED {asset_id}: {e}")

def main():
    if not API_KEY:
        print("WARNING: AI_IMAGE_API_KEY not set. This script will not generate images.")
        print("Set it as an environment variable or edit this file.")
    categories = list(CATEGORY_CONFIG.keys())
    for cat in categories:
        generate_category(cat)
    print("Done.")

if __name__ == "__main__":
    main()
