#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AI 出图后批量标准化工具
功能：重命名、裁剪/缩放、格式转换、文件名合规化
运行：python tools/art_batch_processor.py <input_dir> <output_dir> [--size 128x128]
"""

import argparse
import os
import re
import shutil
import sys
from pathlib import Path

SUPPORTED_EXT = ('.png', '.jpg', '.jpeg', '.webp', '.bmp')


def sanitize_filename(name: str) -> str:
    """去掉 AI 提示词长尾、特殊字符、中文字符，生成项目可用文件名"""
    # 常见 AI 长尾分隔符
    for sep in ['_2026-', '_AI_', '_generated_', '_低多边形', '_游戏', '_素材', '_图标',
                '_prompt_', '_by_', '_artstation', '_concept_']:
        if sep in name:
            name = name.split(sep)[0]
    # 只保留字母、数字、下划线、连字符
    name = re.sub(r'[^\w\-]', '_', name)
    # 连续下划线合并
    name = re.sub(r'_+', '_', name)
    # 去掉首尾下划线
    name = name.strip('_')
    return name.lower()


def parse_size(size_str: str):
    """解析 128x128 格式"""
    parts = size_str.lower().split('x')
    if len(parts) != 2:
        raise ValueError(f"Invalid size format: {size_str}")
    return int(parts[0]), int(parts[1])


def try_import_pil():
    try:
        from PIL import Image
        return Image
    except ImportError:
        return None


def process_folder(input_dir: Path, output_dir: Path, target_size=None, padding=False):
    Image = try_import_pil()
    if Image is None and target_size:
        print("错误：需要裁剪/缩放功能，请先安装 Pillow：pip install Pillow")
        sys.exit(1)

    if not output_dir.exists():
        output_dir.mkdir(parents=True)

    files = [f for f in input_dir.iterdir() if f.is_file() and f.suffix.lower() in SUPPORTED_EXT]
    if not files:
        print(f"未在 {input_dir} 找到图片文件")
        return

    processed = 0
    for f in files:
        new_stem = sanitize_filename(f.stem)
        new_name = new_stem + '.png'
        out_path = output_dir / new_name

        if target_size and Image:
            img = Image.open(f).convert('RGBA')
            if padding:
                # 按比例缩放后居中，保持画布尺寸
                img.thumbnail(target_size, Image.LANCZOS)
                canvas = Image.new('RGBA', target_size, (0, 0, 0, 0))
                x = (target_size[0] - img.width) // 2
                y = (target_size[1] - img.height) // 2
                canvas.paste(img, (x, y), img)
                canvas.save(out_path)
            else:
                # 直接拉伸到目标尺寸
                img = img.resize(target_size, Image.LANCZOS)
                img.save(out_path)
        else:
            # 仅重命名+转 png
            if f.suffix.lower() == '.png':
                shutil.copy2(f, out_path)
            elif Image:
                img = Image.open(f).convert('RGBA')
                img.save(out_path)
            else:
                print(f"跳过 {f.name}：缺少 Pillow 且不是 PNG")
                continue

        processed += 1
        print(f"{f.name} -> {out_path}")

    print(f"\n完成：处理 {processed} 个文件，输出到 {output_dir}")


def main():
    parser = argparse.ArgumentParser(description='AI 出图批量标准化')
    parser.add_argument('input_dir', help='AI 出图目录')
    parser.add_argument('output_dir', help='标准化后输出目录')
    parser.add_argument('--size', default=None, help='目标尺寸，如 128x128')
    parser.add_argument('--padding', action='store_true', help='按比例缩放并居中填充，避免拉伸变形')
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir)

    if not input_dir.exists():
        print(f"输入目录不存在：{input_dir}")
        sys.exit(1)

    target_size = parse_size(args.size) if args.size else None
    process_folder(input_dir, output_dir, target_size, args.padding)


if __name__ == '__main__':
    main()
