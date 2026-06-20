#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
批量生成 AI 美术 Prompt 清单
运行：python tools/generate_prompts.py
输出：docs/generated_prompts.md
"""

import os

OUTPUT = os.path.join(os.path.dirname(os.path.dirname(__file__)), "docs", "generated_prompts.md")

STYLE_LOCK = (
    "low poly tactical sci-fi game asset, clean hardsurface geometry, cel-shaded, "
    "dark teal and electric orange accent, subtle glow, transparent background, "
    "isometric view, military cyberpunk, no text, no watermark, high quality render"
)

NEGATIVE_PROMPT = (
    "realistic, photorealistic, blurry, low quality, watermark, signature, text, "
    "letters, UI elements, frame, border, cropped, duplicate, mutated hands, extra "
    "fingers, malformed limbs, messy background, gradient background"
)

PLAYER_CLASSES = [
    ("player_assault", "突击兵", "A male tactical assault soldier in blue accented heavy armor, holding a bullpup assault rifle, neutral pose"),
    ("player_sniper", "狙击手", "A female sniper in blue stealth suit, hood down, holding a long sniper rifle, crouched aim pose"),
    ("player_medic", "医疗兵", "A combat medic in white and blue tactical gear, holding a med-gun, ready stance"),
    ("player_scout", "侦察兵", "A nimble scout in light black and blue armor, holding an SMG, agile pose"),
    ("player_heavy", "重装兵", "A bulky heavy gunner in massive blue-gray power armor, holding a rotary machine gun"),
]

ENEMIES_CH1 = [
    ("enemy_sentry_basic", "基础哨兵", "A red and black humanoid combat robot, simple blocky design, glowing red eye, holding an energy rifle"),
    ("enemy_sentry_sniper", "狙击哨兵", "A tall red and black sniper robot with a long barrel energy rifle, scoped pose"),
    ("enemy_drone_assault", "突击无人机", "A small red and black assault drone with twin cannons, hovering"),
    ("enemy_shadow_mercenary", "暗影雇佣兵", "A cloaked mercenary in dark red hooded suit, holding a silenced pistol"),
    ("enemy_data_sentinel", "数据哨兵BOSS", "A massive floating boss mech with data core in chest, red and black, multiple weapon arms"),
]

PORTRAITS = [
    ("portrait_assault", "突击兵肖像", "Close-up portrait of a male tactical soldier with short hair, blue-lit visor, stern expression, front-facing"),
    ("portrait_sniper", "狙击手肖像", "Close-up portrait of a female sniper with calm focused eyes, hood, blue ambient light"),
    ("portrait_medic", "医疗兵肖像", "Close-up portrait of a young medic, gentle but determined expression, white and blue gear"),
    ("portrait_scout", "侦察兵肖像", "Close-up portrait of a nimble scout, sharp eyes, short hair, mischievous smirk"),
    ("portrait_heavy", "重装兵肖像", "Close-up portrait of a muscular heavy gunner, scarred face, confident grin"),
]

WEAPONS = [
    ("weapon_assault_rifle", "突击步枪", "A futuristic bullpup assault rifle, dark teal and orange accents"),
    ("weapon_sniper_rifle", "狙击步枪", "A long futuristic sniper rifle with scope, dark teal and orange accents"),
    ("weapon_machine_gun", "机枪", "A heavy rotary machine gun, massive barrel, dark teal and orange accents"),
    ("weapon_energy_dagger", "能量匕首", "A glowing energy dagger with teal blade, compact"),
]

EFFECTS = [
    ("effect_explosion", "爆炸特效", "Explosion frame N/8, low poly fireball, bright orange and yellow, expanding shockwave, game VFX"),
    ("effect_muzzle_flash", "枪口火焰", "Muzzle flash frame N/4, bright yellow-white cone burst, game VFX"),
    ("effect_heal", "治疗特效", "Heal effect frame N/8, rising green teal energy particles and cross symbol, game VFX"),
    ("effect_shield", "护盾特效", "Barrier effect frame N/8, hexagonal energy shield, blue glow, game VFX"),
]

TILE_THEMES = [
    ("theme_warehouse", "仓库地形", "industrial warehouse interior, concrete floor, metal walls, yellow safety lines, scattered crates"),
    ("theme_city_ruins", "城市废墟", "post-apocalyptic city ruins, broken asphalt, scattered debris, ruined buildings, muted blue-gray and orange"),
]

OBJECTS = [
    ("obj_crate", "补给箱", "A metal supply crate with teal accent stripes, closed"),
    ("obj_wall", "掩体墙", "A concrete and metal barrier wall, half-height cover"),
    ("obj_terminal", "终端机", "A glowing holographic terminal station, teal screen"),
]


def make_prompt(subject_desc: str, extra: str = "") -> str:
    parts = [subject_desc, STYLE_LOCK]
    if extra:
        parts.insert(1, extra)
    return ", ".join(parts) + "."


def write_md(path: str) -> None:
    lines = ["# AI 生成 Prompt 清单\n", f"生成时间：自动生成\n", f"## 通用风格锁\n", f"```\n{STYLE_LOCK}\n```\n", f"## 负面提示词\n", f"```\n{NEGATIVE_PROMPT}\n```\n"]

    sections = [
        ("玩家职业战斗精灵（64x64 / 128x128 PNG，透明背景）", PLAYER_CLASSES, "isometric game sprite, neutral pose, facing 3/4 camera, clean silhouette"),
        ("第一章敌人战斗精灵", ENEMIES_CH1, "isometric game sprite, facing 3/4 camera, clean silhouette"),
        ("角色肖像（256x256 PNG）", PORTRAITS, "close-up portrait, dark background, front-facing, no text"),
        ("武器图标（64x64 PNG，透明背景）", WEAPONS, "weapon icon, centered, 45 degree angle, dark background, subtle rim light"),
        ("特效序列帧（替换占位图）", EFFECTS, "transparent background, low poly, military sci-fi, no text"),
        ("地形主题", TILE_THEMES, "isometric tactical grid tileset texture, top-down view, seamless tiling"),
        ("地图物件（64x64 PNG，透明背景）", OBJECTS, "prop for tactical grid game, isometric view, no text"),
    ]

    for title, items, extra in sections:
        lines.append(f"## {title}\n")
        for key, name, desc in items:
            prompt = make_prompt(desc, extra)
            lines.append(f"### {name}（{key}）\n")
            lines.append(f"**Prompt：**\n")
            lines.append(f"```\n{prompt}\n```\n")
            lines.append(f"**Negative prompt：**\n")
            lines.append(f"```\n{NEGATIVE_PROMPT}\n```\n")
            lines.append("\n")

    with open(path, "w", encoding="utf-8") as f:
        f.writelines(lines)


if __name__ == "__main__":
    write_md(OUTPUT)
    print(f"Prompts generated: {OUTPUT}")
