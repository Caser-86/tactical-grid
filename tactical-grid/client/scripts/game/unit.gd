## 单位基类
## 所有战斗单位（玩家/敌人）的公共属性和行为
extends Node2D
class_name Unit

signal unit_selected(unit)
signal unit_moved(unit, from: Vector2i, to: Vector2i)
signal unit_attacked(attacker, target, result: Dictionary)
signal unit_damaged(unit, damage: int)
signal unit_died(unit)
signal ap_changed(unit, current_ap: int)

# 基础属性
@export var unit_name: String = "Unit"
@export var team: String = "player"  # player / enemy
@export var job: String = "assault"

# 六维属性
var stats: Dictionary = {
	"str": 5, "agi": 5, "int": 5, "vit": 5, "per": 5, "wil": 5
}

# 派生属性
var max_hp: int = 100
var current_hp: int = 100
var max_ap: int = 2
var current_ap: int = 2
var move_points: int = 5
var vision_range: int = 5
var base_hit: int = 50
var crit_chance: float = 0.05
var crit_multiplier: float = 1.5
var dodge: float = 0.05
var armor: int = 0

# 位置
var grid_pos: Vector2i = Vector2i.ZERO
var height: int = 0  # 0/1/2

# 状态
var is_alive: bool = true
var is_downed: bool = false
var status_effects: Array[Dictionary] = []  # 状态效果列表
var equipment: Dictionary = {}

# 武器
var weapon_range: Array[int] = [1, 5]
var weapon_damage: Array[int] = [20, 30]
var weapon_optimal_range: int = 3

func _ready() -> void:
	add_to_group(team + "_units")
	add_to_group("units")

## 初始化属性
func setup(data: Dictionary) -> void:
	unit_name = data.get("name", "Unit")
	job = data.get("job", "assault")
	stats = data.get("stats", stats)
	max_hp = data.get("max_hp", 100)
	current_hp = max_hp
	max_ap = data.get("max_ap", 2)
	current_ap = max_ap
	move_points = data.get("move_points", 5)
	vision_range = data.get("vision_range", 5)
	armor = data.get("armor", 0)

## 刷新 AP（回合开始时）
func refresh_ap() -> void:
	current_ap = max_ap
	ap_changed.emit(self, current_ap)

## 消耗 AP
func spend_ap(amount: int) -> bool:
	if current_ap < amount:
		return false
	current_ap -= amount
	ap_changed.emit(self, current_ap)
	return true

## 受到伤害
func take_damage(amount: int) -> void:
	if not is_alive:
		return
	current_hp -= amount
	unit_damaged.emit(self, amount)
	if current_hp <= 0:
		current_hp = 0
		is_alive = false
		is_downed = true
		unit_died.emit(self)

## 恢复 HP
func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, max_hp)

## 移动到新位置
func move_to(new_pos: Vector2i) -> void:
	var old_pos = grid_pos
	grid_pos = new_pos
	unit_moved.emit(self, old_pos, new_pos)

## 添加状态效果
func add_status(effect_id: String, duration: int, data: Dictionary = {}) -> void:
	# 检查是否已有相同状态
	for effect in status_effects:
		if effect.id == effect_id:
			effect.duration = maxi(effect.duration, duration)
			return
	status_effects.append({
		"id": effect_id,
		"duration": duration,
		"data": data
	})

## 移除状态效果
func remove_status(effect_id: String) -> void:
	status_effects = status_effects.filter(func(e): return e.id != effect_id)

## 回合开始时处理状态
func on_turn_start() -> void:
	# 处理 DOT（持续伤害）
	for effect in status_effects:
		match effect.id:
			"bleed":
				take_damage(int(max_hp * 0.05))
			"burn":
				take_damage(int(max_hp * 0.08))
			"poison":
				take_damage(int(max_hp * 0.03))

	# 减少持续时间
	for effect in status_effects:
		effect.duration -= 1
	# 移除过期状态
	status_effects = status_effects.filter(func(e): return e.duration > 0)

## 获取某属性的当前值（含状态修正）
func get_stat(stat_name: String) -> int:
	var base = stats.get(stat_name, 5)
	var modifier = 0
	for effect in status_effects:
		if effect.data.has(stat_name):
			modifier += effect.data[stat_name]
	return base + modifier

## 是否可以行动
func can_act() -> bool:
	return is_alive and current_ap > 0 and not has_status("stun")

## 是否可以移动
func can_move() -> bool:
	return is_alive and not has_status("stun") and not has_status("rooted")

## 是否有某状态
func has_status(effect_id: String) -> bool:
	return status_effects.any(func(e): return e.id == effect_id)
