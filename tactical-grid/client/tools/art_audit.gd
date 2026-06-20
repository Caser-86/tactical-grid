@tool
extends EditorScript

## 美术资源审计工具
## 运行方式：Godot 编辑器 → 文件系统 → 右键 tools/art_audit.gd → 运行

const OUTPUT_MD := "res://docs/art_assets_checklist.md"
const OUTPUT_CSV := "res://docs/art_assets_checklist.csv"

const CATEGORIES := {
	"units": {"dir": "res://assets/units/", "ext": [".png"]},
	"characters": {"dir": "res://assets/characters/generated/", "ext": [".png"]},
	"weapons": {"dir": "res://assets/weapons/", "ext": [".png"]},
	"skills": {"dir": "res://assets/skills/", "ext": [".png"]},
	"items": {"dir": "res://assets/items/", "ext": [".png"]},
	"effects": {"dir": "res://assets/effects/generated/", "ext": [".png"]},
	"tiles": {"dir": "res://assets/tiles/generated/", "ext": [".png"]},
	"objects": {"dir": "res://assets/objects/", "ext": [".png"]},
	"ui": {"dir": "res://assets/ui/", "ext": [".png"]},
	"audio_sfx": {"dir": "res://assets/audio/sfx/", "ext": [".ogg", ".wav"]},
	"audio_bgm": {"dir": "res://assets/audio/bgm/", "ext": [".ogg", ".wav"]},
}

const AI_KEYWORDS := [
	"generated", "游戏", "素材", "low poly", "风格", "透明背景",
	"2026-", "AI_generated", "midjourney", "stable_diffusion"
]

func _run() -> void:
	var rows: Array[Dictionary] = []

	for category in CATEGORIES:
		var info = CATEGORIES[category]
		var files = _list_files(info.dir, info.ext)
		for f in files:
			var row = {
				"category": category,
				"filename": f.get_file(),
				"path": f,
				"size_kb": _file_size_kb(f),
				"ai_marked": _looks_ai_generated(f),
				"status": "OK",
				"note": "",
			}
			rows.append(row)

	# 标记关键缺失资源
	_check_missing(rows)

	rows.sort_custom(func(a, b): return a.category < b.category if a.category != b.category else a.filename < b.filename)

	_write_md(rows)
	_write_csv(rows)

	print("Art audit complete: ", OUTPUT_MD, ", ", OUTPUT_CSV)

func _list_files(dir_path: String, exts: Array) -> Array[String]:
	var result: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return result
	var dir = DirAccess.open(dir_path)
	if not dir:
		return result
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if not dir.current_is_dir():
			for ext in exts:
				if file.ends_with(ext):
					result.append(dir_path + file)
					break
		file = dir.get_next()
	dir.list_dir_end()
	return result

func _file_size_kb(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	return FileAccess.get_file_as_bytes(path).size() / 1024

func _looks_ai_generated(path: String) -> bool:
	var lower = path.to_lower()
	for kw in AI_KEYWORDS:
		if kw in lower:
			return true
	return false

func _check_missing(rows: Array[Dictionary]) -> void:
	var expected := {
		"units": ["player_assault", "player_sniper", "player_medic", "player_scout", "player_heavy"],
		"characters": ["portrait_assault", "portrait_sniper", "portrait_medic", "portrait_scout", "portrait_heavy"],
		"objects": ["crate", "wall", "evac", "terminal", "resource"],
		"ui": ["游戏UI图标集_战术战棋游戏_包含移动_攻击_技能_物品_警_2026-06-17T18-05-49"],
	}
	var existing_files := {}
	for row in rows:
		existing_files[row.path] = true

	for cat in expected:
		for name in expected[cat]:
			var dir = CATEGORIES[cat]["dir"]
			var found = false
			for ext in CATEGORIES[cat]["ext"]:
				if FileAccess.file_exists(dir + name + ext):
					found = true
					break
			if not found:
				rows.append({
					"category": cat,
					"filename": name + ".png",
					"path": dir + name + ".png",
					"size_kb": 0,
					"ai_marked": false,
					"status": "MISSING",
					"note": "Expected by code/theme",
				})

func _write_md(rows: Array[Dictionary]) -> void:
	var md := "# 美术资源审计表\n\n"
	md += "生成时间：" + Time.get_datetime_string_from_system() + "\n\n"
	md += "| 类别 | 文件名 | 大小(KB) | AI标记 | 状态 | 备注 |\n"
	md += "|---|---|---:|:---|:---|:---|\n"
	for row in rows:
		md += "| %s | %s | %d | %s | %s | %s |\n" % [
			row.category,
			row.filename,
			row.size_kb,
			"是" if row.ai_marked else "否",
			row.status,
			row.note
		]
	md += "\n## 统计\n\n"
	md += "- 总数：%d\n" % rows.size()
	md += "- AI 标记：%d\n" % rows.filter(func(r): return r.ai_marked).size()
	md += "- 缺失：%d\n" % rows.filter(func(r): return r.status == "MISSING").size()

	var file = FileAccess.open(OUTPUT_MD, FileAccess.WRITE)
	file.store_string(md)
	file.close()

func _write_csv(rows: Array[Dictionary]) -> void:
	var csv := "category,filename,size_kb,ai_marked,status,note\n"
	for row in rows:
		csv += "%s,%s,%d,%s,%s,\"%s\"\n" % [
			row.category,
			row.filename,
			row.size_kb,
			"yes" if row.ai_marked else "no",
			row.status,
			row.note.replace("\"", "\"\"")
		]
	var file = FileAccess.open(OUTPUT_CSV, FileAccess.WRITE)
	file.store_string(csv)
	file.close()
