## 存档管理器
## 本地 + 云端存档
extends Node

const SAVE_DIR = "user://saves/"
const MAX_LOCAL_SAVES = 3

func _ready() -> void:
	_ensure_save_dir()

func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

## 保存游戏
func save_game(save_data: Dictionary, slot: int = 0) -> bool:
	var path = SAVE_DIR + "save_%d.json" % slot
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		print("Failed to open save file: ", path)
		return false

	save_data["save_version"] = "1.1.0"
	save_data["save_time"] = Time.get_unix_time_from_system()

	var json_str = JSON.stringify(save_data, "  ")
	file.store_string(json_str)
	file.close()

	# 同步到云端
	_sync_to_cloud(save_data, slot)

	return true

## 加载游戏
func load_game(slot: int = 0) -> Dictionary:
	var path = SAVE_DIR + "save_%d.json" % slot
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var text = file.get_as_text()
	file.close()

	var data = JSON.parse_string(text)
	return data if data else {}

## 获取所有本地存档
func get_local_saves() -> Array:
	var saves: Array = []
	for slot in range(MAX_LOCAL_SAVES):
		var data = load_game(slot)
		if data.size() > 0:
			saves.append({
				"slot": slot,
				"chapter": data.get("campaign_progress", {}).get("current_chapter", 1),
				"playtime": data.get("playtime_seconds", 0),
				"save_time": data.get("save_time", 0),
			})
	return saves

## 自动存档
func auto_save(save_data: Dictionary) -> bool:
	return save_game(save_data, 0)

## 删除存档
func delete_save(slot: int) -> void:
	var path = SAVE_DIR + "save_%d.json" % slot
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

## 云存档同步
func _sync_to_cloud(save_data: Dictionary, slot: int) -> void:
	if GameManager.auth_token == "":
		return  # 未登录，跳过

	var api = ApiClient.new()
	add_child(api)
	api.set_token(GameManager.auth_token)

	var result = await api.upload_save({
		"save_type": "auto",
		"save_data": JSON.stringify(save_data),
		"version": "1.1.0",
	})

	api.queue_free()

	if result.code != 0:
		print("Cloud sync failed: ", result.message)

## 从云端加载最新存档
func load_from_cloud() -> Dictionary:
	if GameManager.auth_token == "":
		return {}

	var api = ApiClient.new()
	add_child(api)
	api.set_token(GameManager.auth_token)

	var result = await api.download_save("latest")
	api.queue_free()

	if result.code != 0:
		return {}

	var save_data_str = result.data.get("save_data", "")
	if save_data_str == "":
		return {}

	return JSON.parse_string(save_data_str)

## 创建默认存档数据
func create_default_save() -> Dictionary:
	return {
		"save_version": "1.1.0",
		"playtime_seconds": 0,
		"campaign_progress": {
			"current_chapter": 1,
			"current_mission": "ch1_m1",
			"completed_missions": [],
			"mission_ratings": {},
			"story_flags": {},
		},
		"characters": [],
		"inventory": [
			{"id": "med_kit", "type": "consumable", "count": 2},
			{"id": "painkiller", "type": "consumable", "count": 1},
			{"id": "grenade", "type": "throwable", "count": 1}
		],
		"resources": {
			"credit": 0,
			"intel": 0,
			"materials": {},
		},
		"settings": {
			"difficulty": "standard",
			"permadeath": false,
		},
		"stats_tracking": {
			"total_kills": 0,
			"total_missions": 0,
			"total_playtime": 0,
		},
	}
