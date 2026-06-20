#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AI 资源替换追踪表
对比 generated/ 目录和成品目录，输出替换进度
运行：python tools/art_replacement_tracker.py
"""

import os
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLIENT_ASSETS = ROOT / "client" / "assets"
OUTPUT_MD = ROOT / "docs" / "art_replacement_tracker.md"
OUTPUT_CSV = ROOT / "docs" / "art_replacement_tracker.csv"

# 成品目录映射：生成目录 -> 成品目录
CATEGORY_MAP = {
    "characters/generated": "characters",
    "effects/generated": "effects",
    "tiles/generated": "tiles",
}


def list_files(path: Path, exts=('.png', '.jpg', '.jpeg')):
    if not path.exists():
        return []
    return [f for f in path.iterdir() if f.is_file() and f.suffix.lower() in exts]


def normalize_name(name: str) -> str:
    """去掉 generated 文件名中可能带有的 AI 提示词长尾，提取核心标识"""
    # 这里简单按常见 AI 文件名模式切分，实际可按需扩展
    for sep in ['_2026-', '_AI_', '_generated_', '_低多边形', '_游戏']:
        if sep in name:
            name = name.split(sep)[0]
    return name.lower().strip()


def build_tracker():
    rows = []
    for generated_dir, final_dir in CATEGORY_MAP.items():
        gen_path = CLIENT_ASSETS / generated_dir
        fin_path = CLIENT_ASSETS / final_dir

        gen_files = list_files(gen_path)
        fin_files = list_files(fin_path)
        fin_names = {normalize_name(f.stem): f.name for f in fin_files}

        for gen in gen_files:
            key = normalize_name(gen.stem)
            replaced = key in fin_names
            rows.append({
                "category": generated_dir.split('/')[0],
                "generated_file": gen.name,
                "final_file": fin_names.get(key, ""),
                "status": "REPLACED" if replaced else "PENDING",
                "note": "" if replaced else "Need AI generated replacement",
            })

    return rows


def write_outputs(rows):
    # CSV
    with open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["category", "generated_file", "final_file", "status", "note"])
        writer.writeheader()
        writer.writerows(rows)

    # Markdown
    lines = ["# AI 资源替换追踪表\n\n"]
    lines.append("| 类别 | generated 文件 | 成品文件 | 状态 | 备注 |\n")
    lines.append("|---|---|---|---|---|\n")
    for r in rows:
        lines.append(f"| {r['category']} | {r['generated_file']} | {r['final_file']} | {r['status']} | {r['note']} |\n")

    total = len(rows)
    replaced = sum(1 for r in rows if r["status"] == "REPLACED")
    lines.append(f"\n## 统计\n\n")
    lines.append(f"- 总数：{total}\n")
    lines.append(f"- 已替换：{replaced} ({replaced/total*100:.1f}%)\n")
    lines.append(f"- 待替换：{total - replaced}\n")

    with open(OUTPUT_MD, "w", encoding="utf-8") as f:
        f.writelines(lines)


if __name__ == "__main__":
    rows = build_tracker()
    write_outputs(rows)
    print(f"Tracker generated: {OUTPUT_MD}, {OUTPUT_CSV}")
    replaced = sum(1 for r in rows if r["status"] == "REPLACED")
    print(f"Progress: {replaced}/{len(rows)} replaced")
