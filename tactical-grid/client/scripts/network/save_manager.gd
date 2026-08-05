## 存档管理器
## 本地存档：支持多槽位、原子写入、备份和损坏恢复
extends Node

const V2CampaignProgress = preload("res://scripts/v2/mission/v2_campaign_progress.gd")
const SAVE_DIR = "user://saves/"
const MAX_LOCAL_SAVES = 3
const SAVE_VERSION = "1.0.0"
const V2_SAVE_DIR = "user://saves_v2/"
const V2_MAX_LOCAL_SAVES = 3
const V2_SAVE_VERSION = "2.0.0"
const V2_GAME_LINE = "v2_infiltration"

func _ready() -> void:
	_ensure_save_dir()
	_ensure_v2_save_dir()

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
			# CODE-P0-04: 先删除损坏的主存档，避免 save_game 把损坏数据备份为 .bak
			if FileAccess.file_exists(final_path):
				DirAccess.remove_absolute(final_path)
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

## ===== V2 独立存档 API =====
## V2 与 V1 使用不同目录和身份字段，避免两个产品线互相读取存档。
func _ensure_v2_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(V2_SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(V2_SAVE_DIR)

func _v2_save_path(slot: int) -> String:
	return V2_SAVE_DIR + "save_%d.json" % slot

func _v2_backup_path(slot: int) -> String:
	return V2_SAVE_DIR + "save_%d.bak" % slot

func _v2_temp_path(slot: int) -> String:
	return V2_SAVE_DIR + "save_%d.tmp" % slot

func create_v2_save() -> Dictionary:
	var data: Dictionary = V2CampaignProgress.create_default()
	data["playtime_seconds"] = 0
	data["save_time"] = 0
	return data

func save_game_v2(save_data: Dictionary, slot: int = 0) -> bool:
	if slot < 0 or slot >= V2_MAX_LOCAL_SAVES:
		push_error("Invalid V2 save slot: " + str(slot))
		return false
	var validation: Dictionary = V2CampaignProgress.validate(save_data)
	if not bool(validation.get("valid", false)):
		return false
	_ensure_v2_save_dir()
	var prepared: Dictionary = save_data.duplicate(true)
	prepared["game_line"] = V2_GAME_LINE
	prepared["save_version"] = V2_SAVE_VERSION
	prepared["save_time"] = Time.get_unix_time_from_system()
	var temp_path := _v2_temp_path(slot)
	var final_path := _v2_save_path(slot)
	var backup_path := _v2_backup_path(slot)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write V2 temp save: " + temp_path)
		return false
	file.store_string(JSON.stringify(prepared, "  "))
	file.close()
	if _read_file(temp_path).is_empty():
		push_error("V2 save verification failed: " + temp_path)
		DirAccess.remove_absolute(temp_path)
		return false
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(backup_path)
		var backup_err := DirAccess.rename_absolute(final_path, backup_path)
		if backup_err != OK:
			push_error("Failed to backup V2 save: " + str(backup_err))
		var finalize_err := DirAccess.rename_absolute(temp_path, final_path)
		if finalize_err != OK:
			push_error("Failed to finalize V2 save: " + str(finalize_err))
			if FileAccess.file_exists(backup_path):
				DirAccess.rename_absolute(backup_path, final_path)
			return false
		return true
	var finalize_err := DirAccess.rename_absolute(temp_path, final_path)
	if finalize_err != OK:
		push_error("Failed to finalize V2 save: " + str(finalize_err))
		return false
	return true

func load_game_v2(slot: int = 0) -> Dictionary:
	if slot < 0 or slot >= V2_MAX_LOCAL_SAVES:
		return {}
	_ensure_v2_save_dir()
	var final_path := _v2_save_path(slot)
	var backup_path := _v2_backup_path(slot)
	var data: Dictionary = _read_and_validate_v2(final_path)
	if not data.is_empty():
		return data
	if FileAccess.file_exists(backup_path):
		push_warning("V2 save file corrupted or missing, trying backup: " + backup_path)
		data = _read_and_validate_v2(backup_path)
		if not data.is_empty():
			if FileAccess.file_exists(final_path):
				DirAccess.remove_absolute(final_path)
			save_game_v2(data, slot)
			return data
	return {}

func _read_and_validate_v2(path: String) -> Dictionary:
	var text := _read_file(path)
	if text.is_empty():
		return {}
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return {}
	var data: Dictionary = parser.data
	var validation: Dictionary = V2CampaignProgress.validate(data)
	if not bool(validation.get("valid", false)):
		return {}
	return data

func get_v2_local_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	for slot in range(V2_MAX_LOCAL_SAVES):
		var data: Dictionary = load_game_v2(slot)
		if not data.is_empty():
			saves.append({
				"slot": slot,
				"mission": data.get("current_mission", ""),
				"rescued_characters": data.get("rescued_characters", []).duplicate(),
				"save_time": data.get("save_time", 0),
			})
	return saves

func has_any_v2_save() -> bool:
	for slot in range(V2_MAX_LOCAL_SAVES):
		if not load_game_v2(slot).is_empty():
			return true
	return false

func delete_v2_save(slot: int) -> void:
	if slot < 0 or slot >= V2_MAX_LOCAL_SAVES:
		return
	for path in [_v2_save_path(slot), _v2_backup_path(slot), _v2_temp_path(slot)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

## 创建默认战役进度
func create_default_campaign_progress() -> Dictionary:
	var first = CampaignRepository.get_first_level()
	return {
		"current_chapter": 1,
		"current_mission": first,
		"completed_missions": [],
		"mission_ratings": {},
		"story_flags": {},
		# CODE-CH1-020: 当前遭遇检查点（最近写入的快照），失败重试时由 BattleController 读取
		"encounter_checkpoint": {},
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
			"ui_scale": 1.0,
			"visual_mode": "normal",
			"reduce_motion": false,
			"pan_speed": 1.0,
			"screen_shake": true,
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
	var version = String(data.get("save_version", "0.0.0"))
	# CODE-P0-04: 拒绝未来版本的存档
	if _is_newer_version(version, SAVE_VERSION):
		push_error("Save version %s is newer than supported %s; refusing to load" % [version, SAVE_VERSION])
		return {}
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

## 比较语义版本号：如果 save_ver 比 supported_ver 新返回 true
func _is_newer_version(save_ver: String, supported_ver: String) -> bool:
	var save_parts = save_ver.split(".")
	var supp_parts = supported_ver.split(".")
	for i in range(maxi(save_parts.size(), supp_parts.size())):
		var s = int(save_parts[i]) if i < save_parts.size() else 0
		var v = int(supp_parts[i]) if i < supp_parts.size() else 0
		if s > v:
			return true
		if s < v:
			return false
	return false

## 补全 settings 内部字段（可访问性等开发期间新增字段）
func _migrate_settings(data: Dictionary) -> void:
	if not data.has("settings"):
		data["settings"] = create_default_save().settings
	var settings = data["settings"]
	# 可访问性字段
	if not settings.has("large_text"):
		settings["large_text"] = false
	if not settings.has("ui_scale"):
		settings["ui_scale"] = 1.0
	if not settings.has("visual_mode"):
		settings["visual_mode"] = "normal"
	if not settings.has("reduce_motion"):
		settings["reduce_motion"] = false
	if not settings.has("pan_speed"):
		settings["pan_speed"] = 1.0
	if not settings.has("screen_shake"):
		settings["screen_shake"] = true
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
	# CODE-CH1-020: 遭遇检查点字段（旧存档没有，补全为空字典）
	if not progress.has("encounter_checkpoint"):
		progress["encounter_checkpoint"] = {}
	data["campaign_progress"] = progress

## CODE-CH1-020: 写入遭遇检查点到 campaign_progress。
## snapshot 由 EncounterCheckpointState.snapshot() 生成。
func set_encounter_checkpoint(save_data: Dictionary, snapshot: Dictionary) -> void:
	if not save_data.has("campaign_progress"):
		save_data["campaign_progress"] = create_default_campaign_progress()
	save_data["campaign_progress"]["encounter_checkpoint"] = snapshot.duplicate(true)

## CODE-CH1-020: 读取当前遭遇检查点；无检查点返回空字典。
func get_encounter_checkpoint(save_data: Dictionary) -> Dictionary:
	var progress = save_data.get("campaign_progress", {})
	return progress.get("encounter_checkpoint", {}).duplicate(true)

## CODE-CH1-020: 清除遭遇检查点（成功完成遭遇或任务后调用）。
func clear_encounter_checkpoint(save_data: Dictionary) -> void:
	if save_data.has("campaign_progress"):
		save_data["campaign_progress"]["encounter_checkpoint"] = {}
