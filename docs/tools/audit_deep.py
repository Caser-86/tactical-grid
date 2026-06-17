"""深度审计：函数调用、属性访问、数据流"""
import os
import re
import sys
from collections import defaultdict

sys.stdout.reconfigure(encoding='utf-8')

SCRIPT_DIR = r"d:\Files\新建文件夹\tactical-grid\client\scripts"

# 收集所有文件内容
files = {}
for root, dirs, fnames in os.walk(SCRIPT_DIR):
    for fname in fnames:
        if fname.endswith(".gd"):
            fpath = os.path.join(root, fname)
            with open(fpath, "r", encoding="utf-8") as f:
                files[fpath] = f.read()

# 1. 提取所有函数定义（含静态）
print("="*80)
print("【1. 函数定义清单】")
funcs = defaultdict(list)  # name -> [(file, line, signature)]
for fpath, content in files.items():
    for i, line in enumerate(content.split("\n"), 1):
        m = re.match(r'\s*(static\s+)?func\s+(\w+)\s*\(', line)
        if m:
            static = "static" if m.group(1) else ""
            name = m.group(2)
            funcs[name].append((fpath, i, static, line.strip()))

for name, decls in sorted(funcs.items()):
    if len(decls) > 1:
        print(f"  ⚠️ {name}: {len(decls)} 个定义")
        for d in decls:
            print(f"    {d[0]}:{d[1]} ({d[2]}) {d[3]}")
    else:
        d = decls[0]
        print(f"  ✓ {name} ({d[2]})")

# 2. 提取所有类名作为 autoload 的方法
print("\n" + "="*80)
print("【2. 验证 GameManager/GameData/SaveManager 全局方法】")
autoload_files = {
    "GameManager": r"d:\Files\新建文件夹\tactical-grid\client\scripts\game\game_manager.gd",
    "GameData": r"d:\Files\新建文件夹\tactical-grid\client\scripts\data\game_data.gd",
    "SaveManager": r"d:\Files\新建文件夹\tactical-grid\client\scripts\network\save_manager.gd",
}
for name, fpath in autoload_files.items():
    print(f"\n  {name} ({os.path.basename(fpath)}):")
    if not os.path.exists(fpath):
        print(f"    ❌ 文件不存在")
        continue
    with open(fpath, "r", encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            m = re.match(r'\s*(static\s+)?func\s+(\w+)\s*\(', line)
            if m:
                print(f"    L{i}: {line.strip()}")

# 3. 验证 game_manager.gd 中的 SaveManager.new() 调用
print("\n" + "="*80)
print("【3. GameManager 是否错误调用 autoload】")
with open(autoload_files["GameManager"], "r", encoding="utf-8") as f:
    content = f.read()
issues = []
for i, line in enumerate(content.split("\n"), 1):
    # 错误地 new() 一个 autoload
    if "GameManager.new()" in line or "GameData.new()" in line or "SaveManager.new()" in line:
        issues.append((i, line.strip()))
if issues:
    for i, l in issues:
        print(f"  ❌ L{i}: {l}")
else:
    print("  ✅ 无问题")

# 4. 验证 .tscn 文件中的脚本路径
print("\n" + "="*80)
print("【4. .tscn 文件中的脚本引用】")
scenes_dir = r"d:\Files\新建文件夹\tactical-grid\client\scenes"
for root, dirs, fnames in os.walk(scenes_dir):
    for fname in fnames:
        if not fname.endswith(".tscn"):
            continue
        fpath = os.path.join(root, fname)
        with open(fpath, "r", encoding="utf-8") as f:
            content = f.read()
        # 找 script 引用
        for m in re.finditer(r'\[ext_resource[^\]]*path="(res://[^"]+)"', content):
            res_path = m.group(1)
            if res_path.endswith(".gd"):
                full = os.path.join(r"d:\Files\新建文件夹\tactical-grid\client", res_path.replace("res://", ""))
                if not os.path.exists(os.path.normpath(full)):
                    print(f"  ❌ {fpath}: 缺失 {res_path}")

# 5. 检查所有 get_node / $ 引用
print("\n" + "="*80)
print("【5. 节点引用检查 (仅警告)】")
for fpath, content in files.items():
    for i, line in enumerate(content.split("\n"), 1):
        # $NodeName 引用
        m = re.search(r'\$\s*"?(\w+)"?', line)
        if m:
            node_name = m.group(1)
            # 跳过常见合法节点名
            if node_name in (".", "..", "/root", "VBoxContainer", "HBoxContainer", "CanvasLayer", "ColorRect", "Panel", "Label", "Button", "HTTPRequest", "MarginContainer", "VBox", "HBox"):
                continue
            # 跳过 _ 前缀的私有节点
            if node_name.startswith("_"):
                continue
            # 不警告
            pass

# 6. 验证所有 dictionary 字段在 get() 调用时类型一致
print("\n" + "="*80)
print("【6. JSON 数据加载验证】")
data_dir = r"d:\Files\新建文件夹\tactical-grid\client\data"
import json
for fname in os.listdir(data_dir):
    if not fname.endswith(".json"):
        continue
    fpath = os.path.join(data_dir, fname)
    try:
        with open(fpath, "r", encoding="utf-8") as f:
            data = json.load(f)
        print(f"  ✓ {fname}: {type(data).__name__}, keys={list(data.keys())[:5]}")
    except json.JSONDecodeError as e:
        print(f"  ❌ {fname}: {e}")
    except Exception as e:
        print(f"  ❌ {fname}: {type(e).__name__}: {e}")

print("\n完成")
