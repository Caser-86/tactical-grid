"""GDScript 静态分析器 - 找出所有潜在问题"""
import os
import re
import sys
from collections import defaultdict

sys.stdout = open(sys.stdout.fileno(), mode='w', encoding='utf-8', buffering=1)

SCRIPT_DIR = r"d:\Files\新建文件夹\tactical-grid\client\scripts"

# 收集所有 .gd 文件
gd_files = []
for root, dirs, files in os.walk(SCRIPT_DIR):
    for fname in files:
        if fname.endswith(".gd"):
            gd_files.append(os.path.join(root, fname))

print(f"扫描 {len(gd_files)} 个 GDScript 文件")
print("="*80)

# 收集所有 class_name
class_names = set()
for fpath in gd_files:
    with open(fpath, "r", encoding="utf-8") as f:
        for line in f:
            m = re.match(r'\s*class_name\s+(\w+)', line)
            if m:
                class_names.add(m.group(1))

print(f"已声明的 class_name: {sorted(class_names)}")
print("="*80)

# 1. 检查未声明的 class_name 引用
print("\n【1. 检查未声明的 class_name 引用】")
issues = []
known_types = class_names | {
    "Node", "Node2D", "Node3D", "Control", "CanvasItem", "Resource",
    "Array", "Dictionary", "String", "int", "float", "bool", "void",
    "Vector2", "Vector2i", "Vector3", "Color", "RandomNumberGenerator",
    "PackedScene", "Texture2D", "Image", "AudioStream", "InputEvent",
    "Object", "Variant", "Callable", "Signal", "Sprite2D", "Label",
    "Button", "VBoxContainer", "HBoxContainer", "Panel", "MarginContainer",
    "SceneTree", "Engine", "OS", "Time", "JSON", "FileAccess",
    "PackedStringArray", "PackedInt32Array", "PackedFloat32Array",
    "Array[Dictionary]", "Array[Array]", "Array[Node]", "Array[String]",
    "Array[int]", "Array[Vector2i]", "Array[Dictionary]"
}

for fpath in gd_files:
    with open(fpath, "r", encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            # 查找 ": TypeName" 形式（变量/参数类型注解）
            # 跳过注释行
            stripped = line.split("#")[0]
            # 匹配 : TypeName 但要避免字符串
            for m in re.finditer(r':\s*([A-Z]\w+)', stripped):
                type_name = m.group(1)
                # 跳过基础类型
                if type_name in known_types:
                    continue
                # 跳过带 # 的注释
                if "#" in line[m.start():]:
                    continue
                issues.append((fpath, i, type_name, line.rstrip()))

if issues:
    print(f"  发现 {len(issues)} 个未声明类型引用：")
    for f, i, t, l in issues[:30]:
        print(f"  {f}:{i}: {t} -> {l[:80]}")
else:
    print("  ✅ 无问题")

# 2. 检查语法残留问题
print("\n【2. 检查语法残留问题】")
syntax_issues = []
for fpath in gd_files:
    with open(fpath, "r", encoding="utf-8") as f:
        lines = f.readlines()
        content = f.read()
    # 重新读内容
    with open(fpath, "r", encoding="utf-8") as f:
        content = f.read()
    lines = content.split("\n")

    for i, line in enumerate(lines, 1):
        # 2a. return X, 多余逗号
        if re.search(r'return\s+[^,\n]+\s*,\s*[\)\n]', line):
            syntax_issues.append((fpath, i, "多余逗号", line))
        # 2b. Node  # Type 残留
        if re.search(r'Node\s+#\s*\w+', line):
            syntax_issues.append((fpath, i, "类型注释残留", line))
        # 2c. 未闭合的括号
        # 跳过字符串
        code = line.split("#")[0]
        opens = code.count("(") + code.count("[") + code.count("{")
        closes = code.count(")") + code.count("]") + code.count("}")
        if opens > closes + 1:  # 容忍跨行情况
            pass  # 太复杂跳过
        # 2d. 多余冒号
        if re.search(r':\s*:', line):
            syntax_issues.append((fpath, i, "多余冒号", line))

if syntax_issues:
    print(f"  发现 {len(syntax_issues)} 个语法问题：")
    for f, i, t, l in syntax_issues[:30]:
        print(f"  {f}:{i}: {t} -> {l[:100]}")
else:
    print("  ✅ 无问题")

# 3. 检查 autoload 引用
print("\n【3. 检查 autoload 引用一致性】")
project_godot_path = r"d:\Files\新建文件夹\tactical-grid\client\project.godot"
with open(project_godot_path, "r", encoding="utf-8") as f:
    pg = f.read()
autoloads = {}
in_autoload = False
for line in pg.split("\n"):
    if "[autoload]" in line:
        in_autoload = True
        continue
    if in_autoload and line.startswith("["):
        in_autoload = False
    if in_autoload and "=" in line:
        key = line.split("=")[0].strip()
        val = line.split("=")[1].strip().strip('"').replace("*", "")
        autoloads[key] = val

print(f"  Autoloads: {autoloads}")

# 检查 autoload 文件是否存在
for name, path in autoloads.items():
    full = os.path.join(r"d:\Files\新建文件夹\tactical-grid\client", path.replace("res://", ""))
    full = os.path.normpath(full)
    if os.path.exists(full):
        print(f"  ✅ {name} -> {path}")
    else:
        print(f"  ❌ {name} -> {path} (文件不存在: {full})")

# 4. 检查所有 res:// 引用
print("\n【4. 检查 res:// 资源引用】")
res_issues = []
for fpath in gd_files:
    with open(fpath, "r", encoding="utf-8") as f:
        content = f.read()
    # 找 res:// 引用
    for m in re.finditer(r'res://([\w/.\-]+)', content):
        res_path = m.group(1)
        full = os.path.join(r"d:\Files\新建文件夹\tactical-grid\client", res_path)
        full = os.path.normpath(full)
        if not os.path.exists(full):
            res_issues.append((fpath, res_path, full))

if res_issues:
    print(f"  发现 {len(res_issues)} 个资源缺失：")
    for f, r, full in res_issues[:30]:
        print(f"  {f}: {r} (不存在)")
else:
    print("  ✅ 所有 res:// 引用都存在")

# 5. 检查 class_name 冲突
print("\n【5. 检查 class_name 冲突】")
class_decls = defaultdict(list)
for fpath in gd_files:
    with open(fpath, "r", encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            m = re.match(r'\s*class_name\s+(\w+)', line)
            if m:
                class_decls[m.group(1)].append((fpath, i))

conflicts = {k: v for k, v in class_decls.items() if len(v) > 1}
if conflicts:
    print(f"  发现 {len(conflicts)} 个 class_name 冲突：")
    for k, v in conflicts.items():
        print(f"  {k}: {v}")
else:
    print("  ✅ 无冲突")

print("\n" + "="*80)
print(f"扫描完成")
