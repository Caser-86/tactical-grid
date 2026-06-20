extends Node

const UI_ICON_ATLAS_PATH := "res://assets/ui/游戏UI图标集_战术战棋游戏_包含移动_攻击_技能_物品_警_2026-06-17T18-05-49.png"
const CELL_SIZE := 64

var _current_theme: String = "warehouse"
var _atlas_texture: Texture2D
var _ui_icon_texture: Texture2D

## 切换当前主题（在加载关卡时调用）
func set_theme(theme_id: String) -> void:
	if theme_id == _current_theme and _atlas_texture:
		return
	_current_theme = theme_id
	_atlas_texture = null

func get_atlas_texture() -> Texture2D:
	if _atlas_texture:
		return _atlas_texture
	var path = "res://assets/tiles/generated/theme_" + _current_theme + ".png"
	if FileAccess.file_exists(path):
		_atlas_texture = load(path)
	else:
		# 回退到默认仓库主题
		_atlas_texture = load("res://assets/tiles/generated/theme_warehouse.png")
	return _atlas_texture

func get_source_texture() -> Texture2D:
	return get_atlas_texture()

## 地形/阻挡都按标准 10x1 网格 atlas 取格子
func get_terrain_region(terrain_id: int) -> Rect2:
	var idx = clampi(terrain_id, 0, 9)
	return Rect2(idx * CELL_SIZE, 0, CELL_SIZE, CELL_SIZE)

func get_blocker_region(block_id: int) -> Rect2:
	# 墙体=6 用第7格，箱子=7 用第8格
	var idx = 7 if block_id == 6 else 8
	return Rect2(idx * CELL_SIZE, 0, CELL_SIZE, CELL_SIZE)

func get_ui_icon_texture() -> Texture2D:
	if _ui_icon_texture:
		return _ui_icon_texture
	_ui_icon_texture = load(UI_ICON_ATLAS_PATH)
	return _ui_icon_texture

func get_ui_icon_region(icon_id: String) -> Rect2:
	match icon_id:
		"move":
			return Rect2(160, 220, 300, 300)
		"attack":
			return Rect2(430, 220, 300, 300)
		"skill":
			return Rect2(700, 220, 300, 300)
		"item":
			return Rect2(160, 500, 300, 300)
		"warning":
			return Rect2(430, 500, 300, 300)
		"refresh":
			return Rect2(700, 500, 300, 300)
		_:
			return Rect2(160, 220, 300, 300)

func clear_cache() -> void:
	_atlas_texture = null
	_ui_icon_texture = null
