## 存档管理器
## 本地存档：支持多槽位、原子写入、备份和损坏恢复
extends Node

const SAVE_DIR = "user://saves/"
const MAX_LOCAL_SAVES = 3
const SAVE_VERSION = "1.0.0"

func _ready() -> void:
	_ensure_save_dir()

func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _save_path(slot: int) -> String:
	return SAVE_DIR + "save_%d.json" % slot

func _backup_path(slot: int) -> String:
	return SAVE_DIR + "save_%d.bak" % slot

func _temp_path(slot: int) -> String:
	return SAVE_DIR + "save_%d.tmp" % slot

## 保存游戏到指定槽位
func save_game(save_data: Dictionary, slot: int = 0) -> bool:
	if slot < 0 or slot >= MAX_LOCAL_SAVES:
		push_error("Invalid save slot: " + str(slot))
		return false

	var prepared = prepare_save_data(save_data)
	var json_str = JSON.stringify(prepared, "  ")
	var temp_path = _temp_path(slot)
	var final_path = _save_path(slot)
	var backup_path = _backup_path(slot)

	# 写入临时文件
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to write temp save: " + temp_path)
		return false
	file.store_string(json_str)
	file.close()

	# 验证临时文件可读
	var verify = _read_file(temp_path)
	if verify.is_empty():
		push_error("Save verification failed: " + temp_path)
		DirAccess.remove_absolute(temp_path)
		return false

	# 如果旧存档存在，先备份
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(backup_path)
		var err = DirAccess.rename_absolute(final_path, backup_path)
		if err != OK:
			push_error("Failed to backup save: " + str(err))

	# 原子替换
	var err = DirAccess.rename_absolute(temp_path, final_path)
	if err != OK:
		push_error("Failed to finalize save: " + str(err))
		# 尝试从备份恢复
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, final_path)
		return false

	return true

## 从指定槽位加载游戏
func load_game(slot: int = 0) -> Dictionary:
	if slot < 0 or slot >= MAX_LOCAL_SAVES:
		return {}

	var final_path = _save_path(slot)
	var backup_path = _backup_path(slot)

	var data = _read_and_validate(final_path)
	if not data.is_empty():
		return data

	# 尝试从备份恢复
	if FileAccess.file_exists(backup_path):
		push_warning("Save file corrupted or missing, trying backup: " + backup_path)
		data = _read_and_validate(backup_path)
		if not data.is_empty():
			# 恢复主存档
			save_game(data, slot)
			return data

	return {}

## 读取文件内容
func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var text = file.get_as_text()
	file.close()
	return text

## 读取并验证存档
func _read_and_validate(path: String) -> Dictionary:
	var text = _read_file(path)
	if text == "":
		return {}
	# JSON.parse_string logs an engine error for intentionally corrupted saves.
	# Use an instance so recovery can treat malformed data as an expected failure.
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {}
	var data = parser.data
	if data == null or not data is Dictionary:
		return {}
	return migrate_if_needed(data)

## 准备保存数据（注入元数据）
func prepare_save_data(save_data: Dictionary) -> Dictionary:
	var copy = save_data.duplicate(true)
	copy["save_version"] = SAVE_VERSION
	copy["save_time"] = Time.get_unix_time_from_system()
	if not copy.has("campaign_progress"):
		copy["campaign_progress"] = create_default_campaign_progress()
	return copy

## 获取所有本地存档摘要
func get_local_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	for slot in range(MAX_LOCAL_SAVES):
		var data = load_game(slot)
		if data.size() > 0:
			saves.append({
				"slot": slot,
				"chapter": data.get("campaign_progress", {}).get("current_chapter", 1),
				"mission": data.get("campaign_progress", {}).get("current_mission", ""),
				"playtime": data.get("playtime_seconds", 0),
				"save_time": data.get("save_time", 0),
			})
	return saves

## 是否存在任意有效存档
func has_any_save() -> bool:
	for slot in range(MAX_LOCAL_SAVES):
		if not load_game(slot).is_empty():
			return true
	return false

## 自动存档（使用槽位 0）
func auto_save(save_data: Dictionary) -> bool:
	return save_game(save_data, 0)

## 删除存档
func delete_save(slot: int) -> void:
	var final_path = _save_path(slot)
	var backup_path = _backup_path(slot)
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(final_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)

## 创建默认战役进度
func create_default_campaign_progress() -> Dictionary:
	var first = CampaignRepository.get_first_level()
	return {
		"current_chapter": 1,
		"current_mission": first,
		"completed_missions": [],
		"mission_ratings": {},
		"story_flags": {},
	}

## 创建默认存档数据
func create_default_save() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"playtime_seconds": 0,
		"campaign_progress": create_default_campaign_progress(),
		"characters": [],
		"inventory": {},
		"resources": {
			"credit": 0,
			"intel": 0,
			"materials": {},
		},
		"settings": {
			"difficulty": "standard",
			"permadeath": false,
			"master_volume": 1.0,
			"music_volume": 1.0,
			"sfx_volume": 1.0,
			"fullscreen": false,
			"resolution": "1280x720",
			"large_text": false,
			"reduce_motion": false,
			"colorblind_mode": "none",
			"subtitle_speed": 1.0,
			"keybindings": {
				"pause": {"keycode": 0, "physical_keycode": 4194305},
				"end_turn": {"keycode": 0, "physical_keycode": 32},
				"next_unit": {"keycode": 0, "physical_keycode": 4194306},
				"toggle_overview": {"keycode": 0, "physical_keycode": 4194333},
				"toggle_network": {"keycode": 0, "physical_keycode": 71},
			},
		},
		"stats_tracking": {
			"total_kills": 0,
			"total_missions": 0,
			"total_playtime": 0,
		},
	}

## 版本迁移（占位，未来扩展）
func migrate_if_needed(data: Dictionary) -> Dictionary:
	var version = data.get("save_version", "0.0.0")
	# 即使版本号相同，也补全 stats_tracking 内部字段（开发期间字段会新增）
	_migrate_stats_tracking(data)
	_migrate_campaign_progress(data)
	_migrate_settings(data)
	if version == SAVE_VERSION:
		return data
	# 简单迁移：补全缺失字段
	var defaults = create_default_save()
	for key in defaults:
		if not data.has(key):
			data[key] = defaults[key]
	data["save_version"] = SAVE_VERSION
	return data

## 补全 settings 内部字段（可访问性等开发期间新增字段）
func _migrate_settings(data: Dictionary) -> void:
	if not data.has("settings"):
		data["settings"] = create_default_save().settings
	var settings = data["settings"]
	# 可访问性字段
	if not settings.has("large_text"):
		settings["large_text"] = false
	if not settings.has("reduce_motion"):
		settings["reduce_motion"] = false
	if not settings.has("colorblind_mode"):
		settings["colorblind_mode"] = "none"
	if not settings.has("subtitle_speed"):
		settings["subtitle_speed"] = 1.0
	if not settings.has("keybindings"):
		settings["keybindings"] = create_default_save().settings.keybindings
	data["settings"] = settings

## 补全 stats_tracking 内部字段（开发期间新增的字段）
## 这些字段在 1.0.0 之前可能不存在，需要补全默认值
func _migrate_stats_tracking(data: Dictionary) -> void:
	if not data.has("stats_tracking"):
		data["stats_tracking"] = {}
	var stats = data["stats_tracking"]
	# 补全所有已知字段
	if not stats.has("total_kills"):
		stats["total_kills"] = 0
	if not stats.has("total_missions"):
		stats["total_missions"] = 0
	if not stats.has("total_playtime"):
		stats["total_playtime"] = 0
	if not stats.has("total_failures"):
		stats["total_failures"] = 0
	if not stats.has("failure_counts"):
		stats["failure_counts"] = {}
	if not stats.has("last_failed_mission"):
		stats["last_failed_mission"] = ""
	if not stats.has("battle_history"):
		stats["battle_history"] = []
	if not stats.has("unlocked_endings"):
		stats["unlocked_endings"] = []
	if not stats.has("game_cleared"):
		stats["game_cleared"] = false
	if not stats.has("ng_plus_count"):
		stats["ng_plus_count"] = 0
	data["stats_tracking"] = stats

## 补全 campaign_progress 内部字段
func _migrate_campaign_progress(data: Dictionary) -> void:
	if not data.has("campaign_progress"):
		data["campaign_progress"] = create_default_campaign_progress()
	var progress = data["campaign_progress"]
	if not progress.has("completed_missions"):
		progress["completed_missions"] = []
	if not progress.has("mission_ratings"):
		progress["mission_ratings"] = {}
	if not progress.has("story_flags"):
		progress["story_flags"] = {}
	if not progress.has("current_chapter"):
		progress["current_chapter"] = 1
	if not progress.has("current_mission"):
		progress["current_mission"] = CampaignRepository.get_first_level()
	data["campaign_progress"] = progress
