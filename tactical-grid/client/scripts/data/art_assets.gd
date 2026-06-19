extends Node

const MENU_BACKGROUND_PATH := "res://assets/ui/战术战棋游戏主菜单背景_废墟城市夜景_赛博朋克风格_蓝色和橙_2026-06-17T18-06-45.png"

var _texture_cache: Dictionary = {}
var _portrait_cache: Dictionary = {}

func get_menu_background() -> Texture2D:
	return _load_texture(MENU_BACKGROUND_PATH)

func get_portrait_for_unit(job_id: String, team: String = "player") -> Texture2D:
	var cache_key := "%s:%s" % [team, job_id]
	if _portrait_cache.has(cache_key):
		return _portrait_cache[cache_key]

	var keywords := _portrait_keywords(job_id, team)
	var texture := _find_character_texture(keywords)
	_portrait_cache[cache_key] = texture
	return texture

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

func _exit_tree() -> void:
	_texture_cache.clear()
	_portrait_cache.clear()
