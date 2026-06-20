"""
AI Asset Prompt Generator
Reads game data JSON and generates Chinese/English prompts for image generation models.
Outputs: prompts/ directory with one .txt per asset.
"""
import json
import os
from pathlib import Path

ROOT = Path(__file__).parent
CLIENT = ROOT.parent.parent
DATA_DIR = CLIENT / "data"
OUT_DIR = ROOT / "prompts"
TEMPLATES = json.loads((ROOT / "prompt_templates.json").read_text("utf-8"))

def load_data(name: str) -> dict:
    return json.loads((DATA_DIR / f"{name}.json").read_text("utf-8"))

def clean(s: str) -> str:
    return s.replace("\n", " ").strip()

def write_prompt(category: str, asset_id: str, prompt_cn: str, prompt_en: str):
    folder = OUT_DIR / category
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{asset_id}_cn.txt").write_text(prompt_cn, "utf-8")
    (folder / f"{asset_id}_en.txt").write_text(prompt_en, "utf-8")

def generate_portraits():
    jobs = load_data("jobs")["jobs"]
    for job_id, info in jobs.items():
        desc = info.get("description", "")
        cn = f"{TEMPLATES['portrait']['prefix']}，{TEMPLATES['portrait']['player'].format(job_name=info['name'], description=desc)}"
        en = f"{TEMPLATES['portrait']['prefix']}, {TEMPLATES['portrait']['player'].format(job_name=info['name'], description=desc)}"
        write_prompt("portraits/player", job_id, clean(cn), clean(en))

    enemies = load_data("enemies")["enemies"]
    for eid, info in enemies.items():
        desc = " ".join(info.get("special", []))
        cn = f"{TEMPLATES['portrait']['prefix']}，{TEMPLATES['portrait']['enemy'].format(job_name=info['name'], description=desc)}"
        en = f"{TEMPLATES['portrait']['prefix']}, {TEMPLATES['portrait']['enemy'].format(job_name=info['name'], description=desc)}"
        write_prompt("portraits/enemy", eid, clean(cn), clean(en))

    bosses = load_data("bosses")["bosses"]
    for bid, info in bosses.items():
        desc = " ".join([p.get("name", "") for p in info.get("phases", [])])
        cn = f"{TEMPLATES['portrait']['prefix']}，{TEMPLATES['portrait']['boss'].format(job_name=info['name'], description=desc)}"
        en = f"{TEMPLATES['portrait']['prefix']}, {TEMPLATES['portrait']['boss'].format(job_name=info['name'], description=desc)}"
        write_prompt("portraits/boss", bid, clean(cn), clean(en))

def generate_unit_sprites():
    jobs = load_data("jobs")["jobs"]
    for job_id, info in jobs.items():
        desc = info.get("description", "")
        cn = f"{TEMPLATES['unit_sprite']['prefix']}，{TEMPLATES['unit_sprite']['player'].format(job_name=info['name'], description=desc)}"
        en = f"{TEMPLATES['unit_sprite']['prefix']}, {TEMPLATES['unit_sprite']['player'].format(job_name=info['name'], description=desc)}"
        write_prompt("units/player", job_id, clean(cn), clean(en))

    enemies = load_data("enemies")["enemies"]
    for eid, info in enemies.items():
        desc = " ".join(info.get("special", []))
        cn = f"{TEMPLATES['unit_sprite']['prefix']}，{TEMPLATES['unit_sprite']['enemy'].format(job_name=info['name'], description=desc)}"
        en = f"{TEMPLATES['unit_sprite']['prefix']}, {TEMPLATES['unit_sprite']['enemy'].format(job_name=info['name'], description=desc)}"
        write_prompt("units/enemy", eid, clean(cn), clean(en))

    bosses = load_data("bosses")["bosses"]
    for bid, info in bosses.items():
        desc = " ".join([p.get("name", "") for p in info.get("phases", [])])
        cn = f"{TEMPLATES['unit_sprite']['prefix']}，{TEMPLATES['unit_sprite']['boss'].format(job_name=info['name'], description=desc)}"
        en = f"{TEMPLATES['unit_sprite']['prefix']}, {TEMPLATES['unit_sprite']['boss'].format(job_name=info['name'], description=desc)}"
        write_prompt("units/boss", bid, clean(cn), clean(en))

def generate_weapon_icons():
    weapons = load_data("weapons")["weapons"]
    for wid, info in weapons.items():
        cn = f"{TEMPLATES['weapon_icon']['prefix']}，{TEMPLATES['weapon_icon']['description'].format(weapon_name=info['name'], special=info.get('special',''))}"
        en = f"{TEMPLATES['weapon_icon']['prefix']}, {TEMPLATES['weapon_icon']['description'].format(weapon_name=info['name'], special=info.get('special',''))}"
        write_prompt("weapons", wid, clean(cn), clean(en))

def generate_item_icons():
    items = load_data("items")["items"]
    for iid, info in items.items():
        cn = f"{TEMPLATES['item_icon']['prefix']}，{TEMPLATES['item_icon']['description'].format(item_name=info['name'], description=info.get('description',''))}"
        en = f"{TEMPLATES['item_icon']['prefix']}, {TEMPLATES['item_icon']['description'].format(item_name=info['name'], description=info.get('description',''))}"
        write_prompt("items", iid, clean(cn), clean(en))

def generate_skill_icons():
    skills = load_data("skills")["skills"]
    for sid, info in skills.items():
        cn = f"{TEMPLATES['skill_icon']['prefix']}，{TEMPLATES['skill_icon']['description'].format(skill_name=info['name'], description=info.get('description',''))}"
        en = f"{TEMPLATES['skill_icon']['prefix']}, {TEMPLATES['skill_icon']['description'].format(skill_name=info['name'], description=info.get('description',''))}"
        write_prompt("skills", sid, clean(cn), clean(en))

def generate_object_prompts():
    for obj_id, desc in TEMPLATES["object"]["descriptions"].items():
        cn = f"{TEMPLATES['object']['prefix']}，{desc}"
        en = f"{TEMPLATES['object']['prefix']}, {desc}"
        write_prompt("objects", obj_id, clean(cn), clean(en))

def generate_tile_themes():
    themes = {
        "warehouse": "仓库/工业区，灰色水泥地面，金属货架，昏暗灯光",
        "city_ruins": "城市废墟，破碎柏油路，瓦砾，霓虹灯残骸，雨夜",
        "desert_outpost": "沙漠前哨，黄沙，岩石，太阳能板，烈日",
        "underground": "地下设施，金属格栅地面，管道，幽蓝应急灯",
        "snow_base": "雪地基地，白雪，冰面，红色警戒线，暴风雪"
    }
    for theme_id, theme_desc in themes.items():
        cn = f"{TEMPLATES['tile_theme']['prefix']}，{TEMPLATES['tile_theme']['description'].format(theme_name=theme_desc)}"
        en = f"{TEMPLATES['tile_theme']['prefix']}, {TEMPLATES['tile_theme']['description'].format(theme_name=theme_id)}"
        write_prompt("tiles", theme_id, clean(cn), clean(en))

def generate_effect_prompts():
    for effect_id, desc in TEMPLATES["effect"]["descriptions"].items():
        cn = f"{TEMPLATES['effect']['prefix']}，{desc}"
        en = f"{TEMPLATES['effect']['prefix']}, {desc}"
        write_prompt("effects", effect_id, clean(cn), clean(en))

def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    generate_portraits()
    generate_unit_sprites()
    generate_weapon_icons()
    generate_item_icons()
    generate_skill_icons()
    generate_object_prompts()
    generate_tile_themes()
    generate_effect_prompts()
    print(f"Prompts generated in: {OUT_DIR}")

if __name__ == "__main__":
    main()
