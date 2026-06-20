#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成更精致的商店图占位（带标题文字和角色剪影）
运行：python tools/generate_store_placeholders.py
输出：assets/store_assets/placeholders/
"""

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "store_assets" / "placeholders"

PALETTE = {
    "bg_dark": (15, 20, 30),
    "bg_mid": (25, 36, 52),
    "teal": (61, 187, 115),
    "orange": (255, 140, 45),
    "grid": (46, 66, 92, 128),
    "text": (230, 235, 242),
}


def try_import_pil():
    try:
        from PIL import Image, ImageDraw, ImageFont
        return Image, ImageDraw, ImageFont
    except ImportError:
        return None


def find_font(ImageFont):
    candidates = [
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/msyhbd.ttc",
        "C:/Windows/Fonts/msyh.ttc",
        "C:/Windows/Fonts/simhei.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return None


def draw_gradient(draw, w, h, c1, c2, vertical=True):
    for y in range(h):
        t = y / h if vertical else 0
        color = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
        draw.line([(0, y), (w, y)], fill=color)


def draw_grid(draw, w, h, spacing, color):
    for x in range(0, w, spacing):
        draw.line([(x, 0), (x, h)], fill=color)
    for y in range(0, h, spacing):
        draw.line([(0, y), (w, y)], fill=color)


def draw_hexagon(draw, center, radius, color, width=2):
    import math
    points = []
    for i in range(6):
        angle = math.radians(60 * i - 30)
        points.append((center[0] + math.cos(angle) * radius, center[1] + math.sin(angle) * radius))
    points.append(points[0])
    draw.line(points, fill=color, width=width)


def draw_circle(draw, center, radius, color):
    draw.ellipse([center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius], fill=color)


def draw_silhouette(draw, cx, cy, h, color):
    """简单角色剪影：头 + 身体 + 武器"""
    import math
    head_r = h * 0.12
    draw_circle(draw, (cx, cy - h * 0.35), head_r, color)
    # 身体
    body = [(cx - h * 0.15, cy - h * 0.25), (cx + h * 0.15, cy - h * 0.25),
            (cx + h * 0.12, cy + h * 0.25), (cx - h * 0.12, cy + h * 0.25)]
    draw.polygon(body, fill=color)
    # 枪
    draw.rectangle([cx + h * 0.05, cy - h * 0.1, cx + h * 0.4, cy - h * 0.04], fill=color)


def generate_icon(path, Image, ImageDraw, ImageFont):
    size = 512
    img = Image.new("RGBA", (size, size), PALETTE["bg_dark"])
    draw = ImageDraw.Draw(img)
    draw_gradient(draw, size, size, PALETTE["bg_dark"], PALETTE["bg_mid"])
    draw_grid(draw, size, size, size // 16, PALETTE["grid"])

    center = (size // 2, size // 2)
    for r in range(int(size * 0.42), int(size * 0.45)):
        draw_circle(draw, center, r, PALETTE["teal"])
    draw_circle(draw, center, size * 0.18, PALETTE["teal"])

    # crosshair
    arm = size * 0.32
    draw.line([(center[0] - arm, center[1]), (center[0] - size * 0.12, center[1])], fill=PALETTE["orange"], width=6)
    draw.line([(center[0] + arm, center[1]), (center[0] + size * 0.12, center[1])], fill=PALETTE["orange"], width=6)
    draw.line([(center[0], center[1] - arm), (center[0], center[1] - size * 0.12)], fill=PALETTE["orange"], width=6)
    draw.line([(center[0], center[1] + arm), (center[0], center[1] + size * 0.12)], fill=PALETTE["orange"], width=6)

    font_path = find_font(ImageFont)
    if font_path:
        font = ImageFont.truetype(font_path, 36)
        draw.text((size // 2, size * 0.92), "TACTICAL GRID", fill=PALETTE["text"], font=font, anchor="mm")
    img.save(path)


def generate_capsule(path, w, h, title, subtitle, Image, ImageDraw, ImageFont):
    img = Image.new("RGBA", (w, h), PALETTE["bg_dark"])
    draw = ImageDraw.Draw(img)
    draw_gradient(draw, w, h, PALETTE["bg_dark"], PALETTE["bg_mid"])
    draw_grid(draw, w, h, max(w, h) // 12, PALETTE["grid"])

    center = (w // 2, h // 2)
    draw_hexagon(draw, center, min(w, h) * 0.28, PALETTE["teal"], 3)
    draw_circle(draw, center, min(w, h) * 0.08, PALETTE["orange"])

    # silhouettes
    draw_silhouette(draw, w * 0.25, h * 0.65, h * 0.5, (40, 60, 80, 200))
    draw_silhouette(draw, w * 0.75, h * 0.65, h * 0.5, (40, 60, 80, 200))

    font_path = find_font(ImageFont)
    if font_path:
        title_font = ImageFont.truetype(font_path, 28)
        sub_font = ImageFont.truetype(font_path, 14)
        draw.text((w * 0.05, h * 0.15), title, fill=PALETTE["text"], font=title_font)
        draw.text((w * 0.05, h * 0.28), subtitle, fill=PALETTE["teal"], font=sub_font)
        draw.text((w * 0.95, h * 0.95), "PLACEHOLDER", fill=(120, 130, 140), font=sub_font, anchor="rd")
    img.save(path)


def generate_screenshot(path, label, Image, ImageDraw, ImageFont):
    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h), PALETTE["bg_dark"])
    draw = ImageDraw.Draw(img)
    draw_gradient(draw, w, h, PALETTE["bg_dark"], PALETTE["bg_mid"])
    draw_grid(draw, w, h, 80, PALETTE["grid"])

    center = (w // 2, h // 2)
    draw_hexagon(draw, center, 200, PALETTE["teal"], 4)
    draw_circle(draw, center, 80, PALETTE["orange"])

    # silhouettes
    draw_silhouette(draw, w * 0.35, h * 0.6, h * 0.25, (40, 60, 80, 180))
    draw_silhouette(draw, w * 0.5, h * 0.65, h * 0.3, (40, 60, 80, 200))
    draw_silhouette(draw, w * 0.65, h * 0.6, h * 0.25, (40, 60, 80, 180))

    font_path = find_font(ImageFont)
    if font_path:
        title_font = ImageFont.truetype(font_path, 72)
        sub_font = ImageFont.truetype(font_path, 24)
        draw.text((w // 2, h * 0.72), label, fill=PALETTE["text"], font=title_font, anchor="mm")
        draw.text((w * 0.98, h * 0.98), "PLACEHOLDER - REPLACE WITH AI GENERATED SCREENSHOT", fill=(120, 130, 140), font=sub_font, anchor="rd")
    img.save(path)


def main():
    pil = try_import_pil()
    if pil is None:
        print("请先安装 Pillow：pip install Pillow")
        return
    Image, ImageDraw, ImageFont = pil

    OUT.mkdir(parents=True, exist_ok=True)

    generate_icon(OUT / "icon_placeholder.png", Image, ImageDraw, ImageFont)
    generate_capsule(OUT / "capsule_main_placeholder.png", 460, 215, "TACTICAL GRID", "Turn-Based Tactical Combat", Image, ImageDraw, ImageFont)
    generate_capsule(OUT / "capsule_vertical_placeholder.png", 600, 900, "TACTICAL\nGRID", "Cyberpunk\nTactical Warfare", Image, ImageDraw, ImageFont)

    screenshots = [
        ("screenshot_01_placeholder.png", "MAIN MENU"),
        ("screenshot_02_placeholder.png", "TACTICAL BATTLE"),
        ("screenshot_03_placeholder.png", "OPERATIONS BASE"),
        ("screenshot_04_placeholder.png", "ROGUELIKE RUN"),
        ("screenshot_05_placeholder.png", "SKILL EFFECTS"),
    ]
    for name, label in screenshots:
        generate_screenshot(OUT / name, label, Image, ImageDraw, ImageFont)

    print(f"Enhanced placeholders generated in: {OUT}")


if __name__ == "__main__":
    main()
