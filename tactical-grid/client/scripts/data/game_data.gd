## 游戏数据管理器（单例）
## 加载和管理所有配置数据
extends Node

var terrain_data: Dictionary = {}
var job_data: Dictionary = {}
var enemy_data: Dictionary = {}
var weapon_data: Dictionary = {}
var item_data: Dictionary = {}
var skill_data: Dictionary = {}
var level_data: Dictionary = {}
var boss_data: Dictionary = {}
var dialogue_data: Dictionary = {}
var achievement_data: Dictionary = {}
var roguelike_data: Dictionary = {}

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
	dialogue_data = _load_json("res://data/dialogues.json")
	achievement_data = _load_json("res://data/achievements.json")
	roguelike_data = _load_json("res://data/roguelike.json")

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Data file not found: " + path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open data file: " + path)
		return {}
	var text = file.get_as_text()
	file.close()
	var json = JSON.parse_string(text)
	if not json:
		push_error("Failed to parse JSON: " + path)
		return {}
	return json

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

## 获取职业所有技能
func get_job_skills(job: String) -> Array:
	var result = []
	for skill_id in skill_data.get("skills", {}):
		var skill = skill_data.skills[skill_id]
		if skill.get("job") == job or skill.get("job") == "all":
			result.append({"id": skill_id, "data": skill})
	return result

## 获取移动成本
func get_move_cost(job: String, terrain_id: int) -> int:
	var matrix = job_data.get("move_cost_matrix", {})
	var job_costs = matrix.get(job, {})
	var cost = job_costs.get(str(terrain_id), 1)
	if job == "scout" and terrain_id in [2, 3, 8]:
		cost = 1
	return int(cost)

## 创建玩家单位
func create_player_unit(job_id: String, name: String = "") -> Unit:
	var unit = Unit.new()
	var job_info = get_job(job_id)

	unit.unit_name = name if name != "" else job_info.get("name", "Soldier")
	unit.job = job_id
	unit.team = "player"
	unit.stats = job_info.get("base_stats", unit.stats)
	unit.stats["level"] = unit.stats.get("level", 3)
	unit.max_hp = job_info.get("base_hp", 100)
	unit.current_hp = unit.max_hp
	unit.move_points = job_info.get("base_move", 5)
	unit.vision_range = job_info.get("base_vision", 5)
	unit.max_ap = 2
	unit.current_ap = 2

	# 根据属性计算派生值
	unit.base_hit = 50 + unit.stats.get("per", 5) * 3
	unit.crit_chance = 0.05 + unit.stats.get("per", 5) * 0.005
	unit.dodge = unit.stats.get("agi", 5) * 0.015
	unit.armor = 0
	unit.max_hp += 20
	unit.current_hp = unit.max_hp
	unit.vision_range += 1
	unit.second_wind_available = true
	match job_id:
		"sniper":
			unit.crit_multiplier += 0.5
			unit.vision_range += 1
		"medic":
			unit.heal_bonus = 1.2
		"scout":
			unit.move_points += 1
			unit.dodge += 0.05
		"assault":
			unit.crit_chance += 0.05

	# 装备默认武器
	var weapons_allowed = job_info.get("weapons_allowed", [])
	if weapons_allowed.size() > 0:
		var weapon_id = weapons_allowed[0]
		var weapon = get_weapon(weapon_id)
		if not weapon.is_empty():
			unit.equipped_weapon = weapon_id
			unit.weapon_range = weapon.get("range", unit.weapon_range)
			unit.weapon_damage = weapon.get("damage", unit.weapon_damage)
			unit.weapon_optimal_range = weapon.get("optimal_range", int((unit.weapon_range[0] + unit.weapon_range[1]) / 2))
			unit.crit_multiplier = weapon.get("crit_multiplier", unit.crit_multiplier)
			unit.base_hit += weapon.get("hit_modifier", 0)

	# 初始化组
	unit._init_group()
	return unit

## 创建敌人单位
func create_enemy_unit(enemy_id: String) -> Unit:
	var unit = Unit.new()
	var enemy_info = get_enemy(enemy_id)
	if enemy_info.is_empty():
		enemy_info = boss_data.get("bosses", {}).get(enemy_id, {})

	unit.unit_name = enemy_info.get("name", "Enemy")
	unit.job = enemy_id
	unit.team = "enemy"
	unit.max_hp = enemy_info.get("hp", 60)
	unit.current_hp = unit.max_hp
	unit.armor = enemy_info.get("armor", 0)
	unit.move_points = enemy_info.get("move", 4)
	unit.vision_range = enemy_info.get("vision", 6)
	unit.max_ap = enemy_info.get("ap", 2)
	unit.current_ap = unit.max_ap

	var weapon_range = enemy_info.get("range", [1, 5])
	unit.weapon_range = weapon_range
	unit.weapon_damage = enemy_info.get("damage", [15, 25])
	unit.weapon_optimal_range = weapon_range[1] / 2

	# 初始化组
	unit._init_group()
	return unit
