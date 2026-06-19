extends Node

const TERRAIN_ATLAS_PATH := "res://assets/tiles/战棋游戏地形贴图集_俯视角_低多边形风格_包含平地_道路_森_2026-06-17T18-06-17.png"
const UI_ICON_ATLAS_PATH := "res://assets/ui/游戏UI图标集_战术战棋游戏_包含移动_攻击_技能_物品_警_2026-06-17T18-05-49.png"

var _atlas_texture: Texture2D
var _ui_icon_texture: Texture2D

func get_atlas_texture() -> Texture2D:
	if _atlas_texture:
		return _atlas_texture
	_atlas_texture = load(TERRAIN_ATLAS_PATH)
	return _atlas_texture

func get_source_texture() -> Texture2D:
	return get_atlas_texture()

func get_terrain_region(terrain_id: int) -> Rect2:
	match terrain_id:
		0:
			return Rect2(54, 42, 285, 281)
		1:
			return Rect2(367, 42, 276, 281)
		2:
			return Rect2(683, 42, 285, 281)
		3:
			return Rect2(54, 695, 285, 270)
		4:
			return Rect2(367, 695, 285, 270)
		5:
			return Rect2(683, 695, 285, 270)
		_:
			return Rect2(54, 42, 285, 281)

func get_blocker_region(block_id: int) -> Rect2:
	match block_id:
		6:
			return Rect2(683, 363, 285, 286)
		7:
			return Rect2(54, 363, 285, 286)
		_:
			return Rect2(54, 42, 285, 281)

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
