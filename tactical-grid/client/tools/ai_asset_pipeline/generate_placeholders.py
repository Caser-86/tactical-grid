"""
Generate placeholder images for all assets so the project can run immediately.
Replace these with AI-generated images later by running the prompts in prompts/.
"""
import json
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).parent
CLIENT = ROOT.parent.parent
DATA_DIR = CLIENT / "data"

TEAM_COLORS = {
    "player": (20, 120, 220),
    "enemy": (220, 60, 60),
    "boss": (180, 40, 220),
    "neutral": (200, 200, 200),
}

def load_data(name: str) -> dict:
    return json.loads((DATA_DIR / f"{name}.json").read_text("utf-8"))

def get_font(size: int):
    # Try common Chinese fonts; fallback to default
    candidates = [
        "C:/Windows/Fonts/msyh.ttc",
        "C:/Windows/Fonts/simsun.ttc",
        "C:/Windows/Fonts/simhei.ttf",
        "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()

def save(img: Image.Image, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")

def draw_rounded_rect(draw, xy, fill, radius=8, outline=None, width=1):
    x0, y0, x1, y1 = xy
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)

def make_placeholder(size: tuple, label: str, color: tuple, sublabel: str = ""):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_rounded_rect(draw, (2, 2, size[0]-2, size[1]-2), (*color, 180), radius=10,
                      outline=(255,255,255,120), width=2)
    font = get_font(16)
    bbox = draw.textbbox((0,0), label, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text(((size[0]-tw)//2, (size[1]-th)//2 - 8), label, font=font, fill=(255,255,255,255))
    if sublabel:
        sfont = get_font(10)
        sbbox = draw.textbbox((0,0), sublabel, font=sfont)
        sw = sbbox[2] - sbbox[0]
        draw.text(((size[0]-sw)//2, (size[1]-th)//2 + 14), sublabel, font=sfont, fill=(220,220,220,220))
    return img

def generate_portraits():
    out = CLIENT / "assets" / "characters" / "generated"
    jobs = load_data("jobs")["jobs"]
    for jid in jobs:
        save(make_placeholder((256, 256), jobs[jid]["name"], TEAM_COLORS["player"], "AI占位"),
             out / f"portrait_{jid}.png")
    enemies = load_data("enemies")["enemies"]
    for eid in enemies:
        save(make_placeholder((256, 256), enemies[eid]["name"], TEAM_COLORS["enemy"], "AI占位"),
             out / f"portrait_{eid}.png")
    bosses = load_data("bosses")["bosses"]
    for bid in bosses:
        save(make_placeholder((256, 256), bosses[bid]["name"], TEAM_COLORS["boss"], "AI占位"),
             out / f"portrait_{bid}.png")

def generate_unit_sprites():
    out = CLIENT / "assets" / "units"
    jobs = load_data("jobs")["jobs"]
    for jid in jobs:
        save(make_placeholder((64, 64), jobs[jid]["name"], TEAM_COLORS["player"]),
             out / f"player_{jid}.png")
    enemies = load_data("enemies")["enemies"]
    for eid in enemies:
        save(make_placeholder((64, 64), enemies[eid]["name"], TEAM_COLORS["enemy"]),
             out / f"enemy_{eid}.png")
    bosses = load_data("bosses")["bosses"]
    for bid in bosses:
        save(make_placeholder((96, 96), bosses[bid]["name"], TEAM_COLORS["boss"]),
             out / f"boss_{bid}.png")

def generate_icons(category: str, data_key: str, size: tuple = (64, 64), sub_key: str = ""):
    out = CLIENT / "assets" / category
    root = load_data(data_key)
    data = root.get(sub_key if sub_key else data_key, {})
    for asset_id, info in data.items():
        name = info.get("name", asset_id)
        color = TEAM_COLORS["player"] if category == "skills" else TEAM_COLORS["neutral"]
        if category == "weapons":
            color = TEAM_COLORS["enemy"]
        save(make_placeholder(size, name, color), out / f"{asset_id}.png")

def generate_objects():
    out = CLIENT / "assets" / "objects"
    templates = json.loads((ROOT / "prompt_templates.json").read_text("utf-8"))
    for oid, desc in templates["object"]["descriptions"].items():
        save(make_placeholder((64, 64), oid, TEAM_COLORS["neutral"], "AI占位"),
             out / f"{oid}.png")

def generate_effects():
    out = CLIENT / "assets" / "effects" / "generated"
    templates = json.loads((ROOT / "prompt_templates.json").read_text("utf-8"))
    for eid in templates["effect"]["descriptions"]:
        save(make_placeholder((64, 64), eid, TEAM_COLORS["neutral"], "VFX占位"),
             out / f"{eid}.png")

def generate_tile_atlases():
    out = CLIENT / "assets" / "tiles" / "generated"
    themes = ["warehouse", "city_ruins", "desert_outpost", "underground", "snow_base"]
    tile_names = ["平地", "道路", "森林", "沙地", "高地", "水域", "墙体", "箱子", "毒池", "桥"]
    for theme in themes:
        img = Image.new("RGBA", (640, 64), (0,0,0,0))
        draw = ImageDraw.Draw(img)
        for i, name in enumerate(tile_names):
            x = i * 64
            color = (40 + i*18, 50 + i*14, 60 + i*10, 200)
            draw.rounded_rectangle((x+1, 1, x+62, 62), radius=6, fill=color, outline=(255,255,255,100), width=1)
            font = get_font(12)
            bbox = draw.textbbox((0,0), name[:2], font=font)
            tw = bbox[2]-bbox[0]
            th = bbox[3]-bbox[1]
            draw.text((x + (64-tw)//2, (64-th)//2 - 6), name[:2], font=font, fill=(255,255,255,230))
        save(img, out / f"theme_{theme}.png")

def main():
    generate_portraits()
    generate_unit_sprites()
    generate_icons("weapons", "weapons")
    generate_icons("weapons", "weapons", sub_key="rare_weapons")
    generate_icons("items", "items")
    generate_icons("skills", "skills")
    generate_objects()
    generate_effects()
    generate_tile_atlases()
    print("Placeholder assets generated. Replace with AI-generated images later.")

if __name__ == "__main__":
    main()
