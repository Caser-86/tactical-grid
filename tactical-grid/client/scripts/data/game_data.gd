## 游戏数据管理器（单例）
## 加载和管理所有配置数据
extends Node

const SAVE_VERSION = "1.0.0"

var terrain_data: Dictionary = {}
var job_data: Dictionary = {}
var enemy_data: Dictionary = {}
var weapon_data: Dictionary = {}
var item_data: Dictionary = {}
var skill_data: Dictionary = {}
var level_data: Dictionary = {}
var boss_data: Dictionary = {}
var achievement_data: Dictionary = {}
var dialogue_data: Dictionary = {}
var roguelike_data: Dictionary = {}

var _load_errors: Array[String] = []

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	terrain_data = _load_json("res://data/terrain.json")
	job_data = _load_json("res://data/jobs.json")
	enemy_data = _load_json("res://data/enemies.json")
	weapon_data = _load_json("res://data/weapons.json")
	item_data = _load_json("res://data/items.json")
	skill_data = _load_json("res://data/skills.json")
	level_data = _load_json("res://data/levels.json")
	boss_data = _load_json("res://data/bosses.json")
	achievement_data = _load_json("res://data/achievements.json")
	dialogue_data = _load_json("res://data/dialogues.json")
	roguelike_data = _load_json("res://data/roguelike.json")

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_load_errors.append("Data file not found: " + path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		_load_errors.append("Failed to open: " + path)
		return {}
	var text = file.get_as_text()
	file.close()
	var json = JSON.parse_string(text)
	if json == null:
		_load_errors.append("Invalid JSON: " + path)
		return {}
	return json

func get_load_errors() -> Array[String]:
	return _load_errors.duplicate()

func has_errors() -> bool:
	return _load_errors.size() > 0

## 获取地形数据
func get_terrain(terrain_id: int) -> Dictionary:
	for key in terrain_data.get("terrains", {}):
		var t = terrain_data.terrains[key]
		if t.id == terrain_id:
			return t
	return {}

## 获取职业数据
func get_job(job_id: String) -> Dictionary:
	return job_data.get("jobs", {}).get(job_id, {})

## 获取敌人数据
func get_enemy(enemy_id: String) -> Dictionary:
	return enemy_data.get("enemies", {}).get(enemy_id, {})

## 获取武器数据
func get_weapon(weapon_id: String) -> Dictionary:
	var w = weapon_data.get("weapons", {}).get(weapon_id, {})
	if w.is_empty():
		w = weapon_data.get("rare_weapons", {}).get(weapon_id, {})
	return w

## 获取物品数据
func get_item(item_id: String) -> Dictionary:
	return item_data.get("items", {}).get(item_id, {})

## 获取技能数据
func get_skill(skill_id: String) -> Dictionary:
	return skill_data.get("skills", {}).get(skill_id, {})

## 获取关卡数据
func get_level(level_id: String) -> Dictionary:
	return level_data.get("levels", {}).get(level_id, {})

## 获取 Boss 数据
func get_boss(boss_id: String) -> Dictionary:
	return boss_data.get("bosses", {}).get(boss_id, {})

## 获取成就数据
func get_achievement(achievement_id: String) -> Dictionary:
	return achievement_data.get("achievements", {}).get(achievement_id, {})

## 获取对话数据
func get_dialogue(dialogue_id: String) -> Dictionary:
	return dialogue_data.get("dialogues", {}).get(dialogue_id, {})

## 获取职业所有技能
func get_job_skills(job: String) -> Array:
	var result = []
	for skill_id in skill_data.get("skills", {}):
		var skill = skill_data.skills[skill_id]
		if skill.get("job") == job or skill.get("job") == "all":
			result.append({id = skill_id, data = skill})
	return result

## 获取移动成本
func get_move_cost(job: String, terrain_id: int) -> int:
	var matrix = job_data.get("move_cost_matrix", {})
	var job_costs = matrix.get(job, {})
	return int(job_costs.get(str(terrain_id), 1))

## 创建玩家单位
func create_player_unit(job_id: String, name: String = "") -> Unit:
	var unit = Unit.new()
	var job_info = get_job(job_id)

	unit.unit_name = name if name != "" else job_info.get("name", "Soldier")
	unit.job = job_id
	unit.team = "player"
	unit.stats = job_info.get("base_stats", unit.stats).duplicate()
	unit.max_hp = job_info.get("base_hp", 100)
	unit.current_hp = unit.max_hp
	unit.move_points = job_info.get("base_move", 5)
	unit.base_move_points = unit.move_points
	unit.vision_range = job_info.get("base_vision", 5)
	unit.max_ap = 2
	unit.current_ap = 2

	# 根据属性计算派生值
	var per = unit.stats.get("per", 5)
	var agi = unit.stats.get("agi", 5)
	unit.base_hit = 50 + per * 3
	unit.crit_chance = 0.05 + per * 0.005
	unit.dodge = agi * 0.015
	unit.armor = 0

	# 默认已学技能：取该职业第一个技能（用于无存档回退场景）
	var job_skills = get_job_skills(job_id)
	if not job_skills.is_empty():
		unit.learned_skills = [job_skills[0].id]
	# 默认可用物品：医疗包（所有职业可用）
	unit.available_items = ["med_kit"]

	return unit

## Create a unit from the V2 character contract without consulting V1 job data.
## V2 combat uses a single deterministic damage value, represented as a two-item
## weapon range so the shared Unit and combat presentation code can be reused.
func create_v2_player_unit(character_data: Dictionary, name_override: String = "") -> Unit:
	var unit := Unit.new()
	var character_id := String(character_data.get("id", "assault"))
	unit.unit_name = name_override if not name_override.is_empty() else String(character_data.get("name", character_id))
	unit.job = character_id
	unit.team = "player"
	unit.max_hp = maxi(1, int(character_data.get("hp", 1)))
	unit.current_hp = unit.max_hp
	unit.move_points = maxi(1, int(character_data.get("move", 1)))
	unit.base_move_points = unit.move_points
	unit.vision_range = maxi(1, int(character_data.get("vision", 1)))
	unit.max_ap = 2
	unit.current_ap = unit.max_ap
	unit.armor = maxi(0, int(character_data.get("armor", 0)))
	var raw_range: Variant = character_data.get("attack_range", [1, 1])
	if raw_range is Array and (raw_range as Array).size() >= 2:
		unit.weapon_range = [int(raw_range[0]), int(raw_range[1])]
	else:
		unit.weapon_range = [1, 1]
	var damage := maxi(1, int(character_data.get("damage", 1)))
	unit.weapon_damage = [damage, damage]
	unit.weapon_optimal_range = int(unit.weapon_range[1])
	unit.learned_skills = [String(character_data.get("ability_id", ""))].filter(func(value: String): return not value.is_empty())
	unit.available_items = []
	unit.base_hit = 100
	unit.crit_chance = 0.0
	unit.dodge = 0.0
	unit.enable_v2_turn_mode()
	return unit

## 创建敌人单位
func create_enemy_unit(enemy_id: String) -> Unit:
	var unit = Unit.new()
	var enemy_info = get_enemy(enemy_id)

	unit.unit_name = enemy_info.get("name", "Enemy")
	unit.job = enemy_id
	unit.team = "enemy"
	unit.max_hp = enemy_info.get("hp", 60)
	unit.current_hp = unit.max_hp
	unit.armor = enemy_info.get("armor", 0)
	unit.move_points = enemy_info.get("move", 4)
	unit.base_move_points = unit.move_points
	unit.vision_range = enemy_info.get("vision", 6)
	unit.max_ap = enemy_info.get("ap", 2)
	unit.current_ap = unit.max_ap

	var weapon_range = enemy_info.get("range", [1, 5])
	unit.weapon_range = weapon_range
	unit.weapon_damage = enemy_info.get("damage", [15, 25])
	unit.weapon_optimal_range = weapon_range[1] / 2

	return unit
