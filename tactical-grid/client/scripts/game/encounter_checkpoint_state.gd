## 遭遇检查点状态
## CODE-CH1-020: 在遭遇边界（A→B、B→C）写入检查点，保存完整战斗状态。
## 仅在遭遇边界写入，不实现逐回合回退。
## 同一检查点重复恢复必须产生相同初始战局（RNG 种子 + 状态快照）。
extends RefCounted
class_name EncounterCheckpointState

## 检查点数据模式版本
const CHECKPOINT_SCHEMA_VERSION := 1

## 创建一个检查点快照。
## 参数：
##   level_id         - 关卡 ID（ch1_m1 等）
##   encounter_id     - 当前遭遇 ID（zone_a / zone_b / ...）
##   turn             - 当前回合数
##   player_units     - Array[Unit]
##   enemy_units      - Array[Unit]
##   alert_state      - 警戒状态字典（来自 AlertState.serialize()）
##   visibility_state - 迷雾状态字典（来自 VisibilityState.serialize()）
##   network_nodes    - 战术网络节点数组
##   facilities       - 设施状态数组
##   objective_phase  - 任务目标阶段字典
##   rng              - RandomNumberGenerator 实例
##   extra            - 可选的额外状态字典
static func snapshot(
	level_id: String,
	encounter_id: String,
	turn: int,
	player_units: Array,
	enemy_units: Array,
	alert_state: Dictionary,
	visibility_state: Dictionary,
	network_nodes: Array,
	facilities: Array,
	objective_phase: Dictionary,
	rng: RandomNumberGenerator,
	extra: Dictionary = {}
) -> Dictionary:
	return {
		"schema_version": CHECKPOINT_SCHEMA_VERSION,
		"level_id": level_id,
		"encounter_id": encounter_id,
		"turn": turn,
		"timestamp": Time.get_unix_time_from_system(),
		"player_units": _serialize_units(player_units),
		"enemy_units": _serialize_units(enemy_units),
		"alert_state": alert_state.duplicate(true),
		"visibility_state": visibility_state.duplicate(true),
		"network_nodes": network_nodes.duplicate(true),
		"facilities": facilities.duplicate(true),
		"objective_phase": objective_phase.duplicate(true),
		"rng_state": serialize_rng(rng),
		"extra": extra.duplicate(true),
	}

## 序列化单位列表为可 JSON 化的字典数组。
## 只保留与重放相关的字段；装备、技能等运行时引用由 BattleController 重建。
static func _serialize_units(units: Array) -> Array:
	var result: Array = []
	for unit in units:
		if unit == null or not is_instance_valid(unit):
			continue
		result.append({
			"entity_id": unit.entity_id,
			"unit_name": unit.unit_name,
			"team": unit.team,
			"job": unit.job,
			"grid_pos": {"x": unit.grid_pos.x, "y": unit.grid_pos.y},
			"height": unit.height,
			"max_hp": unit.max_hp,
			"current_hp": unit.current_hp,
			"max_ap": unit.max_ap,
			"current_ap": unit.current_ap,
			"move_points": unit.move_points,
			"base_move_points": unit.base_move_points,
			"is_alive": unit.is_alive,
			"is_downed": unit.is_downed,
			"status_effects": unit.status_effects.duplicate(true),
			"armor": unit.armor,
			"current_shield": unit.current_shield,
			"max_shield": unit.max_shield,
		})
	return result

## 序列化 RNG 状态。
## Godot 的 RandomNumberGenerator 在 GDScript 中只能可靠地暴露 seed。
## 子状态无法跨实例直接复制，但同一种子从零开始会重现相同序列。
## 因此快照保存 seed；恢复时重新设置 seed 即可让后续随机序列确定。
## 若调用方希望保留 RNG 中间进度，应在快照前确保 RNG 处于已知位置
## （例如每个遭遇边界从 seed 重新开始）。
static func serialize_rng(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"seed": int(rng.seed),
	}

## 从快照恢复 RNG 状态。
## 返回一个新的 RandomNumberGenerator，已设置相同 seed。
static func restore_rng(rng_state: Dictionary) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(rng_state.get("seed", 0))
	return rng

## 验证快照完整性。
## 返回 {valid: bool, errors: Array[String]}
static func validate(snapshot: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var schema := int(snapshot.get("schema_version", 0))
	if schema != CHECKPOINT_SCHEMA_VERSION:
		errors.append("Unsupported checkpoint schema_version: %d" % schema)
	if String(snapshot.get("level_id", "")) == "":
		errors.append("Checkpoint missing level_id")
	if String(snapshot.get("encounter_id", "")) == "":
		errors.append("Checkpoint missing encounter_id")
	if not snapshot.has("player_units") or not (snapshot.get("player_units") is Array):
		errors.append("Checkpoint missing player_units array")
	if not snapshot.has("enemy_units") or not (snapshot.get("enemy_units") is Array):
		errors.append("Checkpoint missing enemy_units array")
	if not snapshot.has("rng_state") or not (snapshot.get("rng_state") is Dictionary):
		errors.append("Checkpoint missing rng_state dictionary")
	return {"valid": errors.is_empty(), "errors": errors}

## 比较两个快照是否等价（用于测试断言）。
## 忽略 timestamp 字段；其余字段深度比较。
static func equivalents(a: Dictionary, b: Dictionary) -> bool:
	var a_copy := a.duplicate(true)
	var b_copy := b.duplicate(true)
	a_copy.erase("timestamp")
	b_copy.erase("timestamp")
	# Dictionary 默认 != 比较引用；用 JSON 字符串做深度比较
	return JSON.stringify(a_copy) == JSON.stringify(b_copy)
