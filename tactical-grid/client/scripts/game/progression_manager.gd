## 角色进度管理器
## 管理角色经验、升级、属性成长、装备和背包
extends Node
class_name ProgressionManager

const XP_PER_LEVEL_BASE = 100
const XP_PER_LEVEL_GROWTH = 50
const MAX_LEVEL = 20

## 创建默认角色数据
func create_character(job_id: String, char_name: String = "") -> Dictionary:
	var job_info = GameData.get_job(job_id)
	var char_data = {
		"id": str(Time.get_ticks_msec()) + "_" + job_id,
		"name": char_name if char_name != "" else job_info.get("name", "Soldier"),
		"job": job_id,
		"level": 1,
		"xp": 0,
		"xp_to_next": XP_PER_LEVEL_BASE,
		"stat_points_unspent": 0,
		"stats": job_info.get("base_stats", {"str": 5, "agi": 5, "int": 5, "vit": 5, "per": 5, "wil": 5}).duplicate(),
		"hp_max": job_info.get("base_hp", 100),
		"move_points": job_info.get("base_move", 5),
		"vision_range": job_info.get("base_vision", 5),
		"ap_max": 2,
		"equipment": {
			"primary": "",
			"secondary": "",
			"armor": "",
			"head": "",
			"accessory1": "",
			"accessory2": "",
		},
		"skills_unlocked": [],
		"skill_points_unspent": 0,
	}
	# 应用初始武器
	var weapons_allowed = job_info.get("weapons_allowed", [])
	if weapons_allowed.size() > 0:
		char_data.equipment.primary = weapons_allowed[0]
	return char_data

## 添加经验值
func add_xp(character: Dictionary, xp_amount: int) -> Dictionary:
	var char_copy = character.duplicate(true)
	char_copy.xp += xp_amount
	# 检查升级
	while char_copy.xp >= char_copy.xp_to_next and char_copy.level < MAX_LEVEL:
		char_copy.xp -= char_copy.xp_to_next
		char_copy.level += 1
		char_copy.stat_points_unspent += 3
		char_copy.skill_points_unspent += 1
		char_copy.xp_to_next = XP_PER_LEVEL_BASE + (char_copy.level - 1) * XP_PER_LEVEL_GROWTH
		# 升级自动提升 HP
		char_copy.hp_max = int(char_copy.hp_max * 1.08)
	return char_copy

## 分配属性点
func allocate_stat(character: Dictionary, stat_name: String) -> Dictionary:
	var char_copy = character.duplicate(true)
	if char_copy.stat_points_unspent <= 0:
		return character
	if not char_copy.stats.has(stat_name):
		return character
	char_copy.stats[stat_name] += 1
	char_copy.stat_points_unspent -= 1
	# 重新计算派生属性
	_recalc_derived(char_copy)
	return char_copy

## 重新计算派生属性
func _recalc_derived(character: Dictionary) -> void:
	var s = character.stats
	character.hp_max = s.get("vit", 5) * 10 + 50
	# 装备加成
	var armor = _get_equipped_weapon_data(character, "armor")
	if not armor.is_empty():
		character.hp_max += armor.get("hp_bonus", 0)

## 装备武器/护甲
func equip_item(character: Dictionary, slot: String, item_id: String) -> Dictionary:
	var char_copy = character.duplicate(true)
	# 检查职业是否允许
	var weapon_data = GameData.get_weapon(item_id)
	if weapon_data.is_empty():
		# 可能是物品不是武器
		weapon_data = GameData.get_item(item_id)
	if weapon_data.is_empty():
		return character
	# 武器需要检查职业
	if slot == "primary" or slot == "secondary":
		var job_info = GameData.get_job(char_copy.job)
		var allowed = job_info.get("weapons_allowed", [])
		if not item_id in allowed:
			return character
	char_copy.equipment[slot] = item_id
	return char_copy

## 卸下装备（将装备返回库存由调用方处理）
func unequip_item(character: Dictionary, slot: String) -> Dictionary:
	var char_copy = character.duplicate(true)
	char_copy.equipment[slot] = ""
	return char_copy

## 学习技能（消耗技能点）
func learn_skill(character: Dictionary, skill_id: String) -> Dictionary:
	var char_copy = character.duplicate(true)
	if skill_id in char_copy.get("skills_unlocked", []):
		return character  # 已学习
	if char_copy.get("skill_points_unspent", 0) <= 0:
		return character  # 无可用技能点
	var skill = GameData.get_skill(skill_id)
	if skill.is_empty():
		return character
	# 必须是同职业或通用
	var skill_job = skill.get("job", "")
	if skill_job != char_copy.job and skill_job != "all":
		return character
	# 等级限制
	var unlock_level = int(skill.get("unlock_level", 1))
	if char_copy.get("level", 1) < unlock_level:
		return character
	char_copy.skills_unlocked.append(skill_id)
	char_copy.skill_points_unspent -= 1
	return char_copy

## 获取角色可学技能列表（按等级和职业过滤）
func get_learnable_skills(character: Dictionary) -> Array:
	var result = []
	var char_level = character.get("level", 1)
	var char_job = character.get("job", "assault")
	var already_learned = character.get("skills_unlocked", [])
	for entry in GameData.get_job_skills(char_job):
		var skill_id = entry.id
		var skill = entry.data
		var unlock_level = int(skill.get("unlock_level", 1))
		if char_level >= unlock_level and not skill_id in already_learned:
			result.append(entry)
	return result

## 获取已装备的武器数据
func _get_equipped_weapon_data(character: Dictionary, slot: String) -> Dictionary:
	var item_id = character.get("equipment", {}).get(slot, "")
	if item_id == "":
		return {}
	return GameData.get_weapon(item_id)

## 创建战斗单位（从角色数据）
func create_battle_unit(character: Dictionary) -> Unit:
	var unit = Unit.new()
	unit.unit_name = character.get("name", "Soldier")
	unit.job = character.get("job", "assault")
	unit.team = "player"
	unit.stats = character.get("stats", {}).duplicate()
	unit.max_hp = character.get("hp_max", 100)
	unit.current_hp = unit.max_hp
	unit.move_points = character.get("move_points", 5)
	unit.base_move_points = unit.move_points
	unit.vision_range = character.get("vision_range", 5)
	unit.max_ap = character.get("ap_max", 2)
	unit.current_ap = unit.max_ap
	unit.equipment = character.get("equipment", {}).duplicate()

	# 应用武器属性
	var primary_id = unit.equipment.get("primary", "")
	if primary_id != "":
		var weapon = GameData.get_weapon(primary_id)
		if not weapon.is_empty():
			unit.weapon_range = weapon.get("range", [1, 5])
			unit.weapon_damage = weapon.get("damage", [20, 30])
			unit.weapon_optimal_range = (unit.weapon_range[0] + unit.weapon_range[1]) / 2
			unit.crit_multiplier = weapon.get("crit_multiplier", 1.5)
			unit.weapon_special = weapon.get("special", "")

	# 应用护甲
	var armor_id = unit.equipment.get("armor", "")
	if armor_id != "":
		var armor = GameData.get_item(armor_id)
		if not armor.is_empty():
			unit.armor = armor.get("armor", 0)

	# 派生属性
	var per = unit.stats.get("per", 5)
	var agi = unit.stats.get("agi", 5)
	unit.base_hit = 50 + per * 3
	unit.crit_chance = 0.05 + per * 0.005
	unit.dodge = agi * 0.015

	# 传入已学技能列表（用于战斗中技能按钮配置驱动）
	unit.learned_skills = character.get("skills_unlocked", []).duplicate()

	return unit

## 获取角色等级对应的经验需求
func get_xp_for_level(level: int) -> int:
	return XP_PER_LEVEL_BASE + (level - 1) * XP_PER_LEVEL_GROWTH

## 创建初始队伍（5个职业各一个）
func create_starter_roster() -> Array:
	var roster = []
	for job_id in ["assault", "sniper", "heavy", "medic", "scout"]:
		roster.append(create_character(job_id))
	return roster
