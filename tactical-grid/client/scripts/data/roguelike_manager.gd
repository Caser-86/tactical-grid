## 深渊远征（Roguelike）模式管理器
## 单例，管理随机关卡、升级、商店、事件等
extends Node
class_name RoguelikeManagerClass

signal run_started
signal floor_completed(floor: int, rewards: Dictionary)
signal run_failed(reason: String)
signal run_victory
signal upgrade_offered(upgrades: Array)
signal shop_opened(items: Array)
signal event_triggered(event_data: Dictionary)

const MAX_FLOORS = 10
const TILE_RADIUS = 2  # 地图路径节点之间的格子数

var current_run: Dictionary = {}
var is_active: bool = false

func _ready() -> void:
	pass

## 开始一次新的远征
func start_run(commander: String = "default") -> void:
	current_run = {
		"commander": commander,
		"current_floor": 0,
		"max_floor_reached": 0,
		"credit": 100,
		"intel": 0,
		"team_state": _init_team_state(),
		"upgrades": [],
		"completed_nodes": [],
		"path": _generate_run_path(),
		"started_at": Time.get_unix_time_from_system(),
		"death_count": 0,
		"kills": 0,
		"elite_kills": 0,
		"boss_kills": 0,
	}
	is_active = true
	run_started.emit()

## 生成远征路径
func _generate_run_path() -> Array:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var path = []
	for floor in range(1, MAX_FLOORS + 1):
		var node_type = _roll_node_type(floor, rng)
		path.append({
			"floor": floor,
			"type": node_type,
			"completed": false,
			"data": _generate_node_data(node_type, floor, rng),
		})
	# 第10层强制为Boss
	path[MAX_FLOORS - 1].type = "boss"
	return path

## 抽取节点类型
func _roll_node_type(floor: int, rng: RandomNumberGenerator) -> String:
	var weights = {
		"normal_battle": 0.30,
		"elite_battle": 0.15,
		"shop": 0.15,
		"event": 0.15,
		"rest": 0.10,
		"treasure": 0.08,
		"mystery": 0.05,
		"boss": 0.02 if floor < MAX_FLOORS else 0,
	}
	var roll = rng.randf()
	var cumulative = 0.0
	for t in weights:
		cumulative += weights[t]
		if roll < cumulative:
			return t
	return "normal_battle"

## 抽取节点的具体数据
func _generate_node_data(node_type: String, floor: int, rng: RandomNumberGenerator) -> Dictionary:
	match node_type:
		"normal_battle":
			return {"enemies": 3 + floor / 3, "enemy_tier": "normal", "terrain": _pick_terrain(floor, rng)}
		"elite_battle":
			return {"enemies": 2 + floor / 4, "enemy_tier": "elite", "terrain": _pick_terrain(floor, rng)}
		"boss":
			return {"boss_id": "roguelike_boss_" + str(floor), "terrain": _pick_terrain(floor, rng)}
		"shop":
			return {"inventory": _generate_shop_inventory(floor, rng), "discount": 0.0}
		"treasure":
			return {"reward": _roll_treasure(floor, rng)}
		"event":
			return _pick_event(floor, rng)
		"rest":
			return {"heal_percent": 0.3, "ap_restore": true}
		"mystery":
			return {"reward": _roll_mystery(floor, rng)}
	return {}

func _pick_terrain(floor: int, rng: RandomNumberGenerator) -> String:
	var terrains = ["warehouse", "city_ruins", "underground", "mountain_fort", "forest"]
	return terrains[rng.randi_range(0, terrains.size() - 1)]

func _generate_shop_inventory(floor: int, rng: RandomNumberGenerator) -> Array:
	var items = []
	# 3-5件商品
	var count = rng.randi_range(3, 5)
	var item_pool = _get_shop_pool(floor)
	for i in range(count):
		var item = item_pool[rng.randi_range(0, item_pool.size() - 1)]
		var price = _calc_price(item, floor, rng)
		items.append({
			"item": item,
			"price": price,
			"stock": 1,
		})
	return items

func _get_shop_pool(floor: int) -> Array:
	# 楼层越高，高级物品越多
	if floor <= 3:
		return ["med_kit_basic", "ammo_ap", "weapon_basic_rifle", "scout_trap"]
	elif floor <= 6:
		return ["med_kit_advanced", "ammo_incendiary", "weapon_advanced_rifle", "scout_emp_mine", "stim_pack"]
	elif floor <= 9:
		return ["med_kit_legendary", "ammo_explosive", "weapon_legendary_rifle", "tactical_visor", "regen_vial"]
	else:
		return ["med_kit_legendary", "weapon_legendary_rifle", "shield_matrix", "thermal_goggles", "plasma_grenade"]

func _calc_price(item: String, floor: int, rng: RandomNumberGenerator) -> int:
	var base = 50 + floor * 30
	return int(base * rng.randf_range(0.8, 1.2))

func _roll_treasure(floor: int, rng: RandomNumberGenerator) -> Dictionary:
	var roll = rng.randf()
	if roll < 0.5:
		# 信用点
		return {"type": "credit", "amount": 100 + floor * 50}
	elif roll < 0.8:
		# 装备
		return {"type": "equipment", "rarity": "rare" if floor < 7 else "epic"}
	else:
		# 升级
		return {"type": "upgrade", "pool": "stat_boosts"}

func _roll_mystery(floor: int, rng: RandomNumberGenerator) -> Dictionary:
	var roll = rng.randf()
	if roll < 0.4:
		return {"type": "credit", "amount": 200 + floor * 100}
	elif roll < 0.7:
		return {"type": "free_upgrade", "rarity": "epic"}
	else:
		return {"type": "trap", "damage": 30}

func _pick_event(floor: int, rng: RandomNumberGenerator) -> Dictionary:
	var events = GameData.roguelike_data.get("roguelike", {}).get("events", [])
	if events.is_empty():
		return {}
	return events[rng.randi_range(0, events.size() - 1)]

func _init_team_state() -> Dictionary:
	return {
		"members": [
			{"name": "Alpha", "hp": 100, "max_hp": 100, "ap": 3, "max_ap": 3, "alive": true, "skills": []},
			{"name": "Lila", "hp": 100, "max_hp": 100, "ap": 3, "max_ap": 3, "alive": true, "skills": []},
			{"name": "Sentinel", "hp": 100, "max_hp": 100, "ap": 3, "max_ap": 3, "alive": true, "skills": []},
			{"name": "Medic", "hp": 100, "max_hp": 100, "ap": 3, "max_ap": 3, "alive": true, "skills": []},
		],
		"kills": 0,
		"upgrades_applied": [],
	}

## 进入下一层
func advance_floor() -> Dictionary:
	if not is_active:
		return {}
	current_run.current_floor += 1
	current_run.max_floor_reached = max(current_run.max_floor_reached, current_run.current_floor)
	if current_run.current_floor > MAX_FLOORS:
		run_victory.emit()
		is_active = false
		return {"victory": true}
	var node = current_run.path[current_run.current_floor - 1]
	return node

## 完成当前层
func complete_floor(rewards: Dictionary) -> void:
	var floor = current_run.current_floor
	current_run.completed_nodes.append(floor)
	current_run.credit += int(rewards.get("credit", 0))
	current_run.intel += int(rewards.get("intel", 0))
	floor_completed.emit(floor, rewards)

## 应用升级
func apply_upgrade(upgrade_id: String) -> bool:
	if not is_active:
		return false
	current_run.upgrades.append(upgrade_id)
	for member in current_run.team_state.members:
		_apply_upgrade_to_member(member, upgrade_id)
	return true

func _apply_upgrade_to_member(member: Dictionary, upgrade_id: String) -> void:
	match upgrade_id:
		"hp_plus_10":
			member.max_hp += 10
			member.hp = min(member.hp + 10, member.max_hp)
		"move_plus_1":
			member.move_bonus = int(member.get("move_bonus", 0)) + 1
		"hit_plus_5":
			member.hit_bonus = int(member.get("hit_bonus", 0)) + 5
		"crit_plus_5":
			member.crit_bonus = int(member.get("crit_bonus", 0)) + 5
		"dodge_plus_5":
			member.dodge_bonus = int(member.get("dodge_bonus", 0)) + 5
		"ap_plus_1":
			member.max_ap += 1
			member.ap += 1
		"first_turn_ap":
			member.first_turn_ap = true
		"heal_on_kill":
			member.heal_on_kill = true
		"overwatch_extra":
			member.overwatch_extra = int(member.get("overwatch_extra", 0)) + 1
		_:
			pass

## 远征失败
func fail_run(reason: String) -> void:
	is_active = false
	run_failed.emit(reason)

## 取得当前路径节点
func get_current_node() -> Dictionary:
	if not is_active:
		return {}
	var floor = current_run.current_floor
	if floor <= 0 or floor > MAX_FLOORS:
		return {}
	return current_run.path[floor - 1]

## 取得指定层节点
func get_floor_node(floor: int) -> Dictionary:
	if floor < 1 or floor > MAX_FLOORS:
		return {}
	return current_run.path[floor - 1]

## 玩家在商店购买
func purchase_item(item_data: Dictionary) -> bool:
	if not is_active:
		return false
	var price = int(item_data.get("price", 0))
	if current_run.credit < price:
		return false
	current_run.credit -= price
	current_run.team_state.inventory = current_run.team_state.get("inventory", [])
	current_run.team_state.inventory.append(item_data.get("item", ""))
	return true

## 完整跑完远征的奖励
func finish_run() -> Dictionary:
	if not current_run:
		return {}
	var total_kills = current_run.team_state.get("kills", 0) + current_run.kills
	var result = {
		"floors_cleared": current_run.max_floor_reached,
		"credit_earned": current_run.credit,
		"intel_earned": current_run.intel,
		"kills": total_kills,
		"upgrades": current_run.upgrades,
		"duration": int(Time.get_unix_time_from_system() - current_run.started_at),
		"is_victory": current_run.max_floor_reached >= MAX_FLOORS,
	}
	# 主线通关后，奖励回到主存档
	if result.get("is_victory", false):
		var resources = GameManager.save_data.get("resources", {})
		resources["credit"] = int(resources.get("credit", 0)) + result.get("credit_earned", 0)
		resources["intel"] = int(resources.get("intel", 0)) + result.get("intel_earned", 0)
		GameManager.save_data["resources"] = resources
		SaveManager.auto_save(GameManager.save_data)
	return result
