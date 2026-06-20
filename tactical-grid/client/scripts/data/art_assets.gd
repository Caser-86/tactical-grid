extends Node

const MENU_BACKGROUND_PATH := "res://assets/ui/战术战棋游戏主菜单背景_废墟城市夜景_赛博朋克风格_蓝色和橙_2026-06-17T18-06-45.png"

var _texture_cache: Dictionary = {}
var _portrait_cache: Dictionary = {}
var _sprite_cache: Dictionary = {}
var _icon_cache: Dictionary = {}
var _unit_frames_cache: Dictionary = {}

func get_menu_background() -> Texture2D:
	return _load_texture(MENU_BACKGROUND_PATH)

## === 肖像（对话框/UI头像） ===
func get_portrait_for_unit(job_id: String, team: String = "player") -> Texture2D:
	var cache_key := "portrait:%s:%s" % [team, job_id]
	if _portrait_cache.has(cache_key):
		return _portrait_cache[cache_key]

	# 优先使用 AI 生成的规范命名肖像
	var generated_path := "res://assets/characters/generated/portrait_" + job_id + ".png"
	var texture := _load_texture(generated_path)
	if not texture:
		var keywords := _portrait_keywords(job_id, team)
		texture = _find_character_texture(keywords)
	_portrait_cache[cache_key] = texture
	return texture

## === 战斗内单位精灵 ===
func get_unit_sprite(job_id: String, team: String = "player") -> Texture2D:
	var cache_key := "sprite:%s:%s" % [team, job_id]
	if _sprite_cache.has(cache_key):
		return _sprite_cache[cache_key]

	var prefix := _team_prefix(team)
	var path := "res://assets/units/" + prefix + "_" + job_id + ".png"
	var texture := _load_texture(path)
	_sprite_cache[cache_key] = texture
	return texture

func _team_prefix(team: String) -> String:
	match team:
		"enemy": return "enemy"
		"boss", "boss_enemy": return "boss"
		_: return "player"


func get_unit_sprite_frames(job_id: String, state: String) -> Array[Texture2D]:
	var cache_key := "frames:%s:%s" % [job_id, state]
	if _unit_frames_cache.has(cache_key):
		return _unit_frames_cache[cache_key]

	var frames: Array[Texture2D] = []
	var dir_path := "res://assets/units/frames/%s/%s/" % [job_id, state]
	var dir := DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if file.ends_with(".png"):
				var tex := _load_texture(dir_path + file)
				if tex:
					frames.append(tex)
			file = dir.get_next()

	frames.sort_custom(func(a, b): return a.resource_path < b.resource_path)
	_unit_frames_cache[cache_key] = frames
	return frames

## === 武器 / 物品 / 技能图标 ===
func get_weapon_icon(weapon_id: String) -> Texture2D:
	return _get_icon("weapon", weapon_id, "res://assets/weapons/" + weapon_id + ".png")

func get_item_icon(item_id: String) -> Texture2D:
	return _get_icon("item", item_id, "res://assets/items/" + item_id + ".png")

func get_skill_icon(skill_id: String) -> Texture2D:
	return _get_icon("skill", skill_id, "res://assets/skills/" + skill_id + ".png")

func _get_icon(category: String, id: String, path: String) -> Texture2D:
	var cache_key := category + ":" + id
	if _icon_cache.has(cache_key):
		return _icon_cache[cache_key]
	var texture := _load_texture(path)
	_icon_cache[cache_key] = texture
	return texture

## === 物体 / 特效 / 地图主题 ===
func get_object_texture(object_type: String) -> Texture2D:
	return _load_texture("res://assets/objects/" + object_type + ".png")

func get_effect_texture(effect_id: String) -> Texture2D:
	return _load_texture("res://assets/effects/generated/" + effect_id + ".png")

func get_tile_theme(theme_id: String) -> Texture2D:
	return _load_texture("res://assets/tiles/generated/theme_" + theme_id + ".png")

## === 保留原有肖像查找逻辑，作为回退 ===
func get_portrait_for_speaker(speaker: String) -> Texture2D:
	return get_portrait_for_unit(_speaker_to_job(speaker), "player")

func _speaker_to_job(speaker: String) -> String:
	var map := {
		"玩家": "assault",
		"指挥官": "assault",
		"突击兵": "assault",
		"狙击手": "sniper",
		"医疗兵": "medic",
		"侦察兵": "scout",
		"重装兵": "heavy",
		"数据哨兵": "data_sentinel",
		"架构师": "architect",
		"哨兵": "sentry_basic",
		"无人机": "drone",
		"刺客": "shadow_mercenary",
		"影子": "shadow_mercenary",
	}
	return map.get(speaker, speaker)

func _portrait_keywords(job_id: String, team: String) -> Array[String]:
	if team == "enemy":
		match job_id:
			"architect":
				return ["架构师", "最终Boss"]
			"data_sentinel":
				return ["数据哨兵", "Boss"]
			"shadow_mercenary":
				return ["隐形刺客", "刺客", "shadow"]
			"heavy":
				return ["重装兵", "重型"]
			"sentry_basic":
				return ["敌方哨兵机器人", "哨兵"]
			"drone":
				return ["攻击无人机", "无人机"]
			_:
				return [job_id]

	match job_id:
		"assault":
			return ["突击兵"]
		"sniper":
			return ["狙击手"]
		"medic":
			return ["医疗兵"]
		"scout":
			return ["侦察兵"]
		"heavy":
			return ["重装兵"]
		_:
			return [_fallback_job_keyword(job_id)]

func _fallback_job_keyword(job_id: String) -> String:
	match job_id:
		"sentry_basic":
			return "哨兵"
		"data_sentinel":
			return "数据哨兵"
		"architect":
			return "架构师"
		"shadow_mercenary":
			return "隐形刺客"
		"drone":
			return "无人机"
		_:
			return job_id

func _find_character_texture(keywords: Array[String]) -> Texture2D:
	var dir := DirAccess.open("res://assets/characters/")
	if not dir:
		return null

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".png"):
			for keyword in keywords:
				if keyword != "" and file_name.contains(keyword):
					var path := "res://assets/characters/" + file_name
					var tex := _load_texture(path)
					dir.list_dir_end()
					return tex
		file_name = dir.get_next()
	dir.list_dir_end()
	return null

func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]

	var texture := load(path)
	_texture_cache[path] = texture
	return texture

func clear_cache() -> void:
	_texture_cache.clear()
	_portrait_cache.clear()
	_sprite_cache.clear()
	_icon_cache.clear()

func _exit_tree() -> void:
	_texture_cache.clear()
	_portrait_cache.clear()
	_sprite_cache.clear()
	_icon_cache.clear()
