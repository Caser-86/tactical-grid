#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AI 美术一键流水线
功能：标准化 AI 出图 → 复制到项目目录 → 更新追踪表 → 审计资源
运行：python tools/ai_pipeline.py [--dry-run]
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLIENT = ROOT / "client"
AI_OUTPUT = ROOT / "ai_output"
CONFIG = ROOT / "tools" / "ai_pipeline_config.json"


def load_config():
    if not CONFIG.exists():
        print(f"配置文件不存在，已创建默认配置：{CONFIG}")
        create_default_config()
    with open(CONFIG, "r", encoding="utf-8") as f:
        return json.load(f)


def create_default_config():
    default = {
        "rules": [
            {"source": "ai_output/assault", "target": "client/assets/units", "size": "128x128", "padding": True},
            {"source": "ai_output/sniper", "target": "client/assets/units", "size": "128x128", "padding": True},
            {"source": "ai_output/medic", "target": "client/assets/units", "size": "128x128", "padding": True},
            {"source": "ai_output/scout", "target": "client/assets/units", "size": "128x128", "padding": True},
            {"source": "ai_output/heavy", "target": "client/assets/units", "size": "128x128", "padding": True},
            {"source": "ai_output/enemies", "target": "client/assets/units", "size": "128x128", "padding": True},
            {"source": "ai_output/warehouse", "target": "client/assets/tiles", "size": "1024x1024", "padding": False},
            {"source": "ai_output/explosion", "target": "client/assets/effects/sequences/explosion_frames", "size": "128x128", "padding": False}
        ]
    }
    with open(CONFIG, "w", encoding="utf-8") as f:
        json.dump(default, f, indent=2, ensure_ascii=False)


def run_batch_processor(source: Path, target: Path, size: str, padding: bool, dry_run: bool):
    """调用 art_batch_processor.py 标准化"""
    script = ROOT / "tools" / "art_batch_processor.py"
    cmd = [sys.executable, str(script), str(source), str(target), "--size", size]
    if padding:
        cmd.append("--padding")

    if dry_run:
        print(f"[DRY-RUN] 将执行：{' '.join(cmd)}")
        return True

    result = subprocess.run(cmd, capture_output=True, text=True)
    print(result.stdout)
    if result.returncode != 0:
        print(result.stderr)
        return False
    return True


def copy_to_final(source_dir: Path, target_dir: Path, dry_run: bool):
    """将标准化后的图复制到项目最终目录"""
    if not source_dir.exists():
        print(f"源目录不存在：{source_dir}")
        return 0

    target_dir.mkdir(parents=True, exist_ok=True)
    copied = 0
    for f in source_dir.iterdir():
        if f.is_file() and f.suffix.lower() == ".png":
            dest = target_dir / f.name
            if dry_run:
                print(f"[DRY-RUN] 将复制 {f} -> {dest}")
            else:
                shutil.copy2(f, dest)
            copied += 1
    return copied


def run_tracker(dry_run: bool):
    script = ROOT / "tools" / "art_replacement_tracker.py"
    if dry_run:
        print(f"[DRY-RUN] 将执行：python {script}")
        return
    result = subprocess.run([sys.executable, str(script)], capture_output=True, text=True)
    print(result.stdout)


def run_audit(dry_run: bool):
    godot = "D:\\Program Files\\Godot\\Godot_v4.6.3-stable_win64_console.exe"
    if not os.path.exists(godot):
        print("未找到 Godot，跳过资源审计。请手动运行：")
        print("godot --headless --path client -s res://tools/art_audit_runner.gd")
        return
    if dry_run:
        print("[DRY-RUN] 将执行 Godot 资源审计")
        return
    result = subprocess.run([godot, "--headless", "--path", str(CLIENT), "-s", "res://tools/art_audit_runner.gd"])
    if result.returncode != 0:
        print("资源审计执行失败")


def main():
    parser = argparse.ArgumentParser(description="AI 美术一键流水线")
    parser.add_argument("--dry-run", action="store_true", help="只打印计划，不实际执行")
    args = parser.parse_args()

    config = load_config()
    total_copied = 0

    print("=== AI 美术一键流水线 ===\n")

    for rule in config["rules"]:
        source = ROOT / rule["source"]
        target = ROOT / rule["target"]
        size = rule["size"]
        padding = rule.get("padding", False)

        print(f"处理：{source.name} -> {target}")

        # 临时标准化目录
        temp_dir = ROOT / "ai_output" / "_processed" / source.name
        if not args.dry_run:
            if temp_dir.exists():
                shutil.rmtree(temp_dir)
            temp_dir.mkdir(parents=True)

        ok = run_batch_processor(source, temp_dir, size, padding, args.dry_run)
        if not ok:
            print(f"跳过 {source.name}：标准化失败\n")
            continue

        copied = copy_to_final(temp_dir, target, args.dry_run)
        total_copied += copied
        print(f"已复制 {copied} 个文件到 {target}\n")

    print("=== 更新追踪表 ===")
    run_tracker(args.dry_run)

    print("\n=== 资源审计 ===")
    run_audit(args.dry_run)

    print(f"\n流水线完成，共复制 {total_copied} 个文件到项目目录。")
    if args.dry_run:
        print("本次为 dry-run，未实际修改文件。")


if __name__ == "__main__":
    main()
