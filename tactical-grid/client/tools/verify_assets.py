"""
Verify that all asset paths referenced in GDScript exist on disk.
"""
import re
import json
from pathlib import Path

ROOT = Path(__file__).parent.parent
SCRIPT_DIR = ROOT / "scripts"
ASSET_DIR = ROOT / "assets"

def find_res_paths():
    pattern = re.compile(r'res://([^"\'\s]+)')
    paths = set()
    for path in SCRIPT_DIR.rglob("*.gd"):
        text = path.read_text("utf-8-sig")
        for m in pattern.findall(text):
            if m.startswith("scripts/") or m.startswith("data/") or m.startswith("scenes/"):
                continue
            paths.add("res://" + m)
    return paths

def exists_res(res_path: str) -> bool:
    if res_path.startswith("res://assets/characters/") and "generated/portrait_" not in res_path:
        # Dynamic scan of characters dir: skip specific file checks for scanned dir
        return True
    local = res_path.replace("res://", "").replace("/", "\\")
    return (ROOT / local).exists()

def main():
    paths = find_res_paths()
    missing = [p for p in sorted(paths) if not exists_res(p)]
    print(f"Checked {len(paths)} referenced asset paths.")
    if missing:
        print(f"MISSING ({len(missing)}):")
        for p in missing:
            print("  -", p)
    else:
        print("All referenced asset paths exist.")

if __name__ == "__main__":
    main()
