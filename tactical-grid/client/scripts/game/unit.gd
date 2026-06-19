## 所有战斗单位（玩家/敌人）的公共属性和行为
extends Node2D
class_name Unit

signal unit_selected(unit)
signal unit_moved(unit, from: Vector2i, to: Vector2i)
signal unit_attacked(attacker, target, result: Dictionary)
signal unit_damaged(unit, damage: int)
signal unit_died(unit)
signal ap_changed(unit, current_ap: int)

@export var unit_name: String = "Unit"
@export var team: String = "player"  # player / enemy
@export var job: String = "assault"

var stats: Dictionary = {
	"str": 5, "agi": 5, "int": 5, "vit": 5, "per": 5, "wil": 5
}

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

var grid_pos: Vector2i = Vector2i.ZERO
var last_grid_pos: Vector2i = Vector2i.ZERO
var height: int = 0

var is_alive: bool = true
var is_downed: bool = false
var status_effects: Array = []
var equipment: Dictionary = {}

var weapon_range: Array = [1, 5]
var weapon_damage: Array = [20, 30]
var weapon_optimal_range: int = 3
var heal_bonus: float = 1.0
var second_wind_available: bool = true

var _group_initialized: bool = false

func _ready() -> void:
	pass

func _init_group() -> void:
	if _group_initialized:
		return
	_group_initialized = true
	add_to_group(team + "_units")
	add_to_group("units")

func setup(data: Dictionary) -> void:
	unit_name = data.get("name", "Unit")
	job = data.get("job", "assault")
	team = data.get("team", team)
	stats = data.get("stats", stats)
	max_hp = data.get("max_hp", 100)
	current_hp = max_hp
	max_ap = data.get("max_ap", 2)
	current_ap = max_ap
	move_points = data.get("move_points", 5)
	vision_range = data.get("vision_range", 5)
	armor = data.get("armor", 0)
	last_grid_pos = grid_pos
	_init_group()

func refresh_ap() -> void:
	current_ap = max_ap
	ap_changed.emit(self, current_ap)

func spend_ap(amount: int) -> bool:
	if current_ap < amount:
		return false
	current_ap -= amount
	ap_changed.emit(self, current_ap)
	return true

func take_damage(amount: int) -> void:
	if not is_alive:
		return

	var damage := maxi(amount, 0)
	if damage <= 0:
		return

	var absorbed := _consume_barrier(damage)
	damage -= absorbed
	if damage <= 0:
		return

	var reduction := _get_damage_reduction_percent()
	if reduction > 0.0:
		damage = maxi(int(round(float(damage) * (1.0 - reduction))), 0)

	if has_status("prevent_death") and damage >= current_hp:
		current_hp = 1
		is_alive = true
		is_downed = false
		return

	if second_wind_available and damage >= current_hp:
		second_wind_available = false
		current_hp = 1
		is_alive = true
		is_downed = false
		add_status("second_wind_used", 999)
		return

	current_hp -= damage
	unit_damaged.emit(self, damage)
	if current_hp <= 0:
		current_hp = 0
		is_alive = false
		is_downed = true
		unit_died.emit(self)

func heal(amount: int) -> void:
	var actual_amount = maxi(int(round(float(amount) * heal_bonus)), 0)
	current_hp = mini(current_hp + actual_amount, max_hp)

func move_to(new_pos: Vector2i) -> void:
	var old_pos = grid_pos
	last_grid_pos = old_pos
	grid_pos = new_pos
	if job == "scout":
		add_status("evasive_step", 1, {dodge = 0.2})
	unit_moved.emit(self, old_pos, new_pos)

func add_status(effect_id: String, duration: int, data: Dictionary = {}) -> void:
	for effect in status_effects:
		if effect.id == effect_id:
			effect.duration = maxi(effect.duration, duration)
			if data.has("amount"):
				var current_amount = int(effect.data.get("amount", 0))
				if effect_id == "barrier":
					effect.data["amount"] = current_amount + int(data.get("amount", 0))
				else:
					effect.data["amount"] = maxi(current_amount, int(data.get("amount", 0)))
			for key in data:
				if key == "amount":
					continue
				effect.data[key] = data[key]
			return
	status_effects.append({
		"id": effect_id,
		"duration": duration,
		"data": data
	})

func remove_status(effect_id: String) -> void:
	status_effects = status_effects.filter(func(e): return e.id != effect_id)

func on_turn_start() -> void:
	for effect in status_effects:
		match effect.id:
			"bleed":
				take_damage(int(max_hp * 0.05))
			"burn":
				take_damage(int(max_hp * 0.08))
			"poison":
				take_damage(int(max_hp * 0.03))

	for effect in status_effects:
		effect.duration -= 1
	status_effects = status_effects.filter(func(e): return e.duration > 0)

func get_stat(stat_name: String) -> int:
	var base = stats.get(stat_name, 5)
	var modifier = 0
	for effect in status_effects:
		if effect.data.has(stat_name):
			modifier += effect.data[stat_name]
	return base + modifier

func can_act() -> bool:
	return is_alive and current_ap > 0 and not has_status("stun")

func can_move() -> bool:
	return is_alive and not has_status("stun") and not has_status("rooted")

func has_status(effect_id: String) -> bool:
	return status_effects.any(func(e): return e.id == effect_id)

func get_status_amount(effect_id: String, key: String = "amount") -> int:
	var total := 0
	for effect in status_effects:
		if effect.id == effect_id:
			total += int(effect.data.get(key, 0))
	return total

func _consume_barrier(incoming_damage: int) -> int:
	var remaining := incoming_damage
	var absorbed := 0
	for effect in status_effects:
		if effect.id != "barrier":
			continue
		var amount := int(effect.data.get("amount", 0))
		if amount <= 0:
			continue
		var used := mini(amount, remaining)
		absorbed += used
		remaining -= used
		effect.data["amount"] = amount - used
		if remaining <= 0:
			break
	status_effects = status_effects.filter(func(e): return e.id != "barrier" or int(e.data.get("amount", 0)) > 0)
	return absorbed

func _get_damage_reduction_percent() -> float:
	var reduction := 0.0
	for effect in status_effects:
		if effect.data.has("reduction"):
			reduction = maxf(reduction, float(effect.data.get("reduction", 0.0)))
		if effect.id in ["damage_reduction", "fortified", "iron_fortress"] and effect.data.has("amount"):
			reduction = maxf(reduction, float(effect.data.get("amount", 0)) / 100.0)
		match effect.id:
			"damage_reduction_50":
				reduction = maxf(reduction, 0.5)
			"heavy_iron_fortress":
				reduction = maxf(reduction, 0.5)
	return clampf(reduction, 0.0, 0.9)
