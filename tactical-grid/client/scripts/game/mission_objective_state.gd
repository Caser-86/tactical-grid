## 任务目标状态机
## 统一管理六类任务目标（extract/destroy/assassinate/escort/steal_data/infiltrate/defend）
## 的计数、HUD 文本、胜负判断，以及关卡特殊规则的执行。
## battle_controller 通过此模块访问目标状态，不再自行维护胜负逻辑。
extends Node
class_name MissionObjectiveState

## 目标文本变化时触发，UI 据此刷新
signal objective_updated(text: String)
## 终端被激活时触发，携带位置和进度
signal terminal_activated(position: Vector2i, activated: int, required: int)
## 可破坏目标被摧毁时触发
signal target_destroyed(position: Vector2i, destroyed: int, required: int)
## 特殊规则被违反时触发（玩家尝试被禁用操作）
signal special_rule_violated(rule_id: String, reason: String)
## 任务阶段事件，用于驱动增援、HUD 反馈等。name 如 terminal_activated / upload_completed。
signal mission_event(name: StringName, payload: Dictionary)

## ===== 任务类型常量 =====
const TYPE_EXTRACT := "extract"
const TYPE_DESTROY := "destroy"
const TYPE_ASSASSINATE := "assassinate"
const TYPE_ESCORT := "escort"
const TYPE_STEAL_DATA := "steal_data"
const TYPE_INFILTRATE := "infiltrate"
const TYPE_DEFEND := "defend"

## ===== 特殊规则常量 =====
const RULE_NO_OVERWATCH := "no_overwatch"
const RULE_NO_ITEMS := "no_items"
const RULE_ENEMY_PASSIVE_TURN_1 := "enemy_passive_turn_1"

## ===== 任务阶段常量（infiltrate 三阶段流） =====
const STAGE_APPROACH := &"approach"
const STAGE_UPLOAD := &"upload"
const STAGE_EVACUATE := &"evacuate"
const STAGE_COMPLETE := &"complete"

## ===== 任务状态 =====
var mission_type: String = TYPE_EXTRACT
var evac_point: Vector2i = Vector2i(-1, -1)
## 撤离区域格。多人小队分别抵达其中任一格即可完成撤离，避免同格重叠。
var evac_cells: Array[Vector2i] = []
var destructible_targets: Array[Vector2i] = []
## pos -> { "hp": int, "max_hp": int, "destroyed": bool }
var destructible_target_states: Dictionary = {}
var targets_destroyed: int = 0
var targets_required: int = 0

## 终端列表
var terminals: Array[Vector2i] = []
var terminals_activated: int = 0
var terminals_required: int = 0

## 护送 VIP 单位引用（escort 任务）
var escort_vip: Node = null
## Boss 单位引用（assassinate 任务，用于胜负判断；阶段逻辑由 battle_controller 维护）
var boss_unit: Node = null

## 防守任务回合限制
var defend_turns_required: int = 0
## 回合上限（defend 任务从 level_config 读取，其他默认 20）
var max_turns: int = 20

## 特殊规则：rule_id -> { "enabled": bool, "reason": String }
var special_rules: Dictionary = {}

## ===== 阶段化任务流（infiltrate） =====
## 当前任务阶段
var mission_stage: StringName = STAGE_APPROACH
## mission_flow 数据契约（来自 map_data.mission_flow）
var mission_flow: Dictionary = {}
## 上传进度 / 所需回合
var upload_progress: int = 0
var upload_turns_required: int = 0
## 上传控制半径（玩家单位到终端的曼哈顿距离阈值）
var upload_hold_radius: int = 1
## 可选资源位置列表
var resource_positions: Array[Vector2i] = []
## 已收集资源：pos -> true
var collected_resources: Dictionary = {}
## 已激活终端：pos -> true（防止重复激活）
var activated_terminals: Dictionary = {}
## 可选资源信用点奖励
var optional_credit: int = 0

## 内部引用
var _players: Array = []
var _enemies: Array = []
var _turn_number: int = 0
## 敌人被动到第几回合（含）；0 表示不被动
var _enemy_passive_until_turn: int = 0


## 初始化任务状态。level_config 来自 levels.json，map_data 来自锁定地图。
## players / enemies 为 battle_controller 已生成的单位列表。
## special_designations 用于把 battle_controller 标记的 boss_unit / escort_vip 传入。
func setup(level_config: Dictionary, map_data: Dictionary, players: Array, enemies: Array, special_designations: Dictionary = {}) -> void:
	_players = players
	_enemies = enemies
	_turn_number = 0
	_enemy_passive_until_turn = 0
	mission_type = String(map_data.get("mission_type", level_config.get("mission_type", TYPE_EXTRACT)))
	# 解析特殊规则（兼容数组和字典两种形式）
	_parse_special_rules(level_config.get("special_rules", []))
	# 从 map_data.objects 提取撤离点、可破坏目标、终端
	_extract_objectives_from_map(map_data, level_config)
	# 接收 battle_controller 标记的特殊单位
	boss_unit = special_designations.get("boss_unit", null)
	escort_vip = special_designations.get("escort_vip", null)
	# 应用 enemy_passive_turn_1：首回合敌人待命
	if is_rule_enabled(RULE_ENEMY_PASSIVE_TURN_1):
		_enemy_passive_until_turn = 1
	# 初始化阶段化任务流（infiltrate）
	_setup_mission_flow(map_data)


## 解析 special_rules，兼容两种形式：
## 1. 数组：["no_overwatch", "no_items"]（使用默认原因）
## 2. 字典：{"no_overwatch": {"enabled": true, "reason": "教学关禁用"}}
func _parse_special_rules(rules_data) -> void:
	special_rules.clear()
	if rules_data is Array:
		for rule_id in rules_data:
			if rule_id is String and rule_id != "":
				special_rules[rule_id] = {
					"enabled": true,
					"reason": _default_reason(rule_id),
				}
	elif rules_data is Dictionary:
		for key in rules_data.keys():
			var rule_id = String(key)
			if rule_id == "":
				continue
			var v = rules_data[key]
			if v is Dictionary:
				special_rules[rule_id] = {
					"enabled": bool(v.get("enabled", true)),
					"reason": String(v.get("reason", _default_reason(rule_id))),
				}
			elif v is bool:
				special_rules[rule_id] = {
					"enabled": v,
					"reason": _default_reason(rule_id),
				}
			else:
				special_rules[rule_id] = {
					"enabled": true,
					"reason": String(v),
				}


func _default_reason(rule_id: String) -> String:
	match rule_id:
		RULE_NO_OVERWATCH:
			return "本关禁用警戒"
		RULE_NO_ITEMS:
			return "本关禁用物品"
		RULE_ENEMY_PASSIVE_TURN_1:
			return "首回合敌人待命"
		_:
			return "本关特殊规则：%s" % rule_id


## 从 map_data.objects 提取撤离点、可破坏目标、终端，写入运行时状态。
func _extract_objectives_from_map(map_data: Dictionary, level_config: Dictionary) -> void:
	destructible_targets.clear()
	destructible_target_states.clear()
	targets_destroyed = 0
	targets_required = 0
	terminals.clear()
	terminals_activated = 0
	terminals_required = 0
	evac_point = Vector2i(-1, -1)
	evac_cells.clear()
	resource_positions.clear()
	for obj in map_data.get("objects", []):
		var t = String(obj.get("type", ""))
		if t == "evac":
			evac_point = Vector2i(int(obj.x), int(obj.y))
			evac_cells = _build_evac_zone(map_data, obj)
		elif t == "destructible_target":
			var pos = Vector2i(int(obj.x), int(obj.y))
			if not pos in destructible_targets:
				destructible_targets.append(pos)
				var hp = int(obj.get("hp", 20))
				destructible_target_states[pos] = {
					"hp": hp,
					"max_hp": hp,
					"destroyed": false,
				}
		elif t == "terminal":
			var pos = Vector2i(int(obj.x), int(obj.y))
			if not pos in terminals:
				terminals.append(pos)
		elif t == "resource":
			var pos = Vector2i(int(obj.x), int(obj.y))
			if not pos in resource_positions:
				resource_positions.append(pos)
	# destroy 任务所需数量取自 objects 中实际目标数，最少 1
	if mission_type == TYPE_DESTROY:
		targets_required = max(destructible_targets.size(), 1)
	# steal_data / infiltrate 需要激活所有终端
	if mission_type in [TYPE_STEAL_DATA, TYPE_INFILTRATE]:
		terminals_required = terminals.size()
	# defend 任务：使用 level_config 的 max_turns 或默认 10
	if mission_type == TYPE_DEFEND:
		defend_turns_required = int(level_config.get("max_turns", 10))
		max_turns = defend_turns_required
	else:
		max_turns = int(level_config.get("max_turns", 20))


## 生成与当前小队规模匹配的撤离区域。
## 锁定地图可用 radius 覆盖默认半径；边缘撤离点会自动向内扩展到可容纳全队。
func _build_evac_zone(map_data: Dictionary, evac_data: Dictionary) -> Array[Vector2i]:
	var size_data: Dictionary = map_data.get("size", {})
	var width := int(size_data.get("width", 0))
	var height := int(size_data.get("height", 0))
	var origin := Vector2i(int(evac_data.get("x", -1)), int(evac_data.get("y", -1)))
	if width <= 0 or height <= 0 or origin.x < 0 or origin.y < 0:
		return []

	var required_slots: int = maxi(1, _players.filter(func(u): return u and u.is_alive).size())
	var radius: int = maxi(1, int(evac_data.get("radius", 1)))
	var max_radius: int = maxi(width, height)
	var cells: Array[Vector2i] = []
	var layers: Dictionary = map_data.get("layers", {})
	var blockers: Array = layers.get("blocker", [])
	while radius <= max_radius:
		cells.clear()
		for y in range(maxi(0, origin.y - radius), mini(height, origin.y + radius + 1)):
			for x in range(maxi(0, origin.x - radius), mini(width, origin.x + radius + 1)):
				if _is_evac_cell_walkable(Vector2i(x, y), blockers):
					cells.append(Vector2i(x, y))
		if cells.size() >= required_slots:
			return cells
		radius += 1
	return cells


func _is_evac_cell_walkable(cell: Vector2i, blockers: Array) -> bool:
	if blockers.is_empty() or cell.y < 0 or cell.y >= blockers.size():
		return true
	var row = blockers[cell.y]
	if not row is Array or cell.x < 0 or cell.x >= row.size():
		return true
	return int(row[cell.x]) == 0


func is_in_evac_zone(position: Vector2i) -> bool:
	if not evac_cells.is_empty():
		return position in evac_cells
	return position == evac_point


## ===== 特殊规则查询 =====

func is_rule_enabled(rule_id: String) -> bool:
	var r = special_rules.get(rule_id, {})
	return bool(r.get("enabled", false))


func get_rule_reason(rule_id: String) -> String:
	var r = special_rules.get(rule_id, {})
	return String(r.get("reason", ""))


## 警戒是否被允许（no_overwatch 规则）
func is_overwatch_allowed() -> bool:
	return not is_rule_enabled(RULE_NO_OVERWATCH)


## 物品是否被允许使用（no_items 规则）
func is_item_use_allowed() -> bool:
	return not is_rule_enabled(RULE_NO_ITEMS)


## 指定回合敌人是否处于被动状态（enemy_passive_turn_1 规则）
func is_enemy_passive(turn_number: int) -> bool:
	if _enemy_passive_until_turn <= 0:
		return false
	return turn_number <= _enemy_passive_until_turn


## ===== 事件回调 =====

## CODE-P0-03: apply_event 是任务状态变更的唯一入口。
## 所有任务事件（终端激活、目标伤害、上传进度、资源收集、回合推进、单位移动、胜利/失败检查）
## 都必须通过此方法路由，不允许直接调用 on_* 方法。
## 返回 Dictionary：成功包含 {success: true, ...}，失败包含 {success: false, reason: String}
func apply_event(event_name: StringName, payload: Dictionary = {}) -> Dictionary:
	match event_name:
		&"terminal_interacted":
			var unit: Node = payload.get("unit", null)
			var term_pos: Vector2i = payload.get("position", Vector2i(-1, -1))
			return on_terminal_interacted(unit, term_pos)
		&"objective_damaged":
			var pos: Vector2i = payload.get("position", Vector2i(-1, -1))
			var damage: int = int(payload.get("damage", 0))
			return on_objective_damaged(pos, damage)
		&"enemy_turn_completed":
			return on_enemy_turn_completed()
		&"resource_interacted":
			var unit: Node = payload.get("unit", null)
			var res_pos: Vector2i = payload.get("position", Vector2i(-1, -1))
			return on_resource_interacted(unit, res_pos)
		&"turn_started":
			var turn: int = int(payload.get("turn", 0))
			var team: String = String(payload.get("team", ""))
			on_turn_started(turn, team)
			return {"success": true}
		&"unit_moved":
			var unit: Node = payload.get("unit", null)
			var from: Vector2i = payload.get("from", Vector2i(-1, -1))
			var to: Vector2i = payload.get("to", Vector2i(-1, -1))
			on_unit_moved(unit, from, to)
			return {"success": true}
		&"check_victory":
			var victory: bool = is_victory()
			return {"success": true, "victory": victory}
		&"check_defeat":
			var defeat: bool = is_defeat()
			return {"success": true, "defeat": defeat}
		_:
			return {"success": false, "reason": "unknown_event", "event": String(event_name)}

## 单位移动后回调（当前不直接改变目标状态，预留用于 escort 路线检查）
func on_unit_moved(_unit: Node, _from: Vector2i, _to: Vector2i) -> void:
	pass


## 玩家单位激活终端。成功返回 {success=true, activated, required}，失败返回 {success=false, reason}
func on_terminal_interacted(unit: Node, term_pos: Vector2i) -> Dictionary:
	# 不可能的状态转换：COMPLETE 阶段不能再激活终端
	if mission_stage == STAGE_COMPLETE:
		return {"success": false, "reason": "mission_already_complete"}
	if not term_pos in terminals:
		return {"success": false, "reason": "not_a_terminal"}
	if not is_instance_valid(unit):
		return {"success": false, "reason": "invalid_unit"}
	# 拒绝重复激活同一终端
	if activated_terminals.has(term_pos):
		return {"success": false, "reason": "already_activated"}
	activated_terminals[term_pos] = true
	terminals_activated += 1
	terminal_activated.emit(term_pos, terminals_activated, terminals_required)
	# infiltrate 模式：首个终端激活后进入 upload 阶段
	if mission_type == TYPE_INFILTRATE and mission_stage == STAGE_APPROACH:
		mission_stage = STAGE_UPLOAD
		mission_event.emit(&"terminal_activated", {
			"position": term_pos,
			"upload_required": upload_turns_required,
		})
	objective_updated.emit(get_status_text())
	return {
		"success": true,
		"activated": terminals_activated,
		"required": terminals_required,
	}


## 可破坏目标受到伤害。返回 {success, destroyed?, remaining?, remaining_hp?}
func on_objective_damaged(position: Vector2i, damage: int) -> Dictionary:
	var state = destructible_target_states.get(position, {})
	if state.is_empty():
		return {"success": false, "reason": "not_a_target"}
	if bool(state.get("destroyed", false)):
		return {"success": false, "reason": "already_destroyed"}
	state["hp"] = max(0, int(state.get("hp", 0)) - damage)
	if int(state["hp"]) <= 0:
		state["destroyed"] = true
		targets_destroyed += 1
		target_destroyed.emit(position, targets_destroyed, targets_required)
		objective_updated.emit(get_status_text())
		return {
			"success": true,
			"destroyed": true,
			"remaining": targets_required - targets_destroyed,
		}
	return {
		"success": true,
		"destroyed": false,
		"remaining_hp": int(state["hp"]),
	}


## 回合开始时回调
func on_turn_started(turn_number: int, _team: String) -> void:
	_turn_number = turn_number


## ===== 阶段化任务流方法 =====

## 获取当前任务阶段
func get_stage() -> StringName:
	return mission_stage


## 初始化 mission_flow 数据契约
func _setup_mission_flow(map_data: Dictionary) -> void:
	mission_flow = (map_data.get("mission_flow", {}) as Dictionary).duplicate(true)
	upload_turns_required = int(mission_flow.get("upload_turns_required", 0))
	upload_hold_radius = int(mission_flow.get("upload_hold_radius", 1))
	optional_credit = int(mission_flow.get("optional_resource_credit", 0))
	# 非 infiltrate 任务或无 mission_flow 时保持 APPROACH 阶段（不影响传统胜负判断）
	mission_stage = STAGE_APPROACH
	upload_progress = 0
	collected_resources.clear()
	activated_terminals.clear()


## 检查是否有玩家单位在终端附近保持上传控制
func _has_upload_control() -> bool:
	for player in _players:
		if player and player.is_alive:
			for terminal_pos in terminals:
				if GridSystem.manhattan_distance(player.grid_pos, terminal_pos) <= upload_hold_radius:
					return true
	return false


## 敌人回合结束回调：推进上传进度。返回 {progress, paused, changed, stage}
func on_enemy_turn_completed() -> Dictionary:
	if mission_stage != STAGE_UPLOAD:
		return {"progress": upload_progress, "paused": false, "changed": false, "stage": mission_stage}
	# 检查上传控制
	if not _has_upload_control():
		objective_updated.emit(get_status_text())
		return {"progress": upload_progress, "paused": true, "changed": false, "stage": mission_stage}
	upload_progress += 1
	if upload_progress >= upload_turns_required:
		mission_stage = STAGE_EVACUATE
		mission_event.emit(&"upload_completed", {"progress": upload_progress})
		objective_updated.emit(get_status_text())
		return {"progress": upload_progress, "paused": false, "changed": true, "stage": mission_stage}
	objective_updated.emit(get_status_text())
	return {"progress": upload_progress, "paused": false, "changed": true, "stage": mission_stage}


## 玩家单位交互可选资源。返回 {success, credit_bonus?, reason?}
func on_resource_interacted(unit: Node, resource_pos: Vector2i) -> Dictionary:
	if not resource_pos in resource_positions:
		return {"success": false, "reason": "not_a_resource"}
	if not is_instance_valid(unit):
		return {"success": false, "reason": "invalid_unit"}
	if collected_resources.has(resource_pos):
		return {"success": false, "reason": "already_collected"}
	collected_resources[resource_pos] = true
	objective_updated.emit(get_status_text())
	return {
		"success": true,
		"credit_bonus": optional_credit,
	}


## 获取结果修饰符（用于星级评分和奖励）
func get_result_modifiers() -> Dictionary:
	return {
		"optional_resource_collected": not collected_resources.is_empty(),
		"optional_credit": optional_credit if not collected_resources.is_empty() else 0,
	}


## ===== 胜负判断 =====

func is_victory() -> bool:
	match mission_type:
		TYPE_EXTRACT:
			return _check_extract_victory()
		TYPE_DESTROY:
			return targets_required > 0 and targets_destroyed >= targets_required
		TYPE_ASSASSINATE:
			if boss_unit and is_instance_valid(boss_unit):
				return not boss_unit.is_alive
			return _enemies.filter(func(u): return u and u.is_alive).is_empty()
		TYPE_ESCORT:
			return _check_escort_victory()
		TYPE_STEAL_DATA, TYPE_INFILTRATE:
			return _check_data_victory()
		TYPE_DEFEND:
			return defend_turns_required > 0 and _turn_number >= defend_turns_required
		_:
			return _enemies.filter(func(u): return u and u.is_alive).is_empty()


## 撤离模式：所有存活玩家单位到达撤离区域。
func _check_extract_victory() -> bool:
	if evac_point.x < 0:
		return false
	var alive = _players.filter(func(u): return u and u.is_alive)
	if alive.is_empty():
		return false
	for u in alive:
		if not is_in_evac_zone(u.grid_pos):
			return false
	return true


## 护送模式：VIP 存活且到达撤离区域。
func _check_escort_victory() -> bool:
	if evac_point.x < 0:
		return false
	if escort_vip == null or not is_instance_valid(escort_vip) or not escort_vip.is_alive:
		return false
	return is_in_evac_zone(escort_vip.grid_pos)


## 窃取数据/潜入：先激活所有终端，再撤离
## infiltrate 模式额外要求上传完成（STAGE_EVACUATE）才能撤离。
func _check_data_victory() -> bool:
	if evac_point.x < 0:
		return false
	if terminals_activated < terminals_required:
		return false
	# infiltrate 模式：上传未完成时撤离被锁定
	if mission_type == TYPE_INFILTRATE and mission_stage != STAGE_EVACUATE and mission_stage != STAGE_COMPLETE:
		return false
	var alive = _players.filter(func(u): return u and u.is_alive)
	if alive.is_empty():
		return false
	for u in alive:
		if not is_in_evac_zone(u.grid_pos):
			return false
	# 胜利时进入 COMPLETE 阶段
	if mission_type == TYPE_INFILTRATE and mission_stage != STAGE_COMPLETE:
		mission_stage = STAGE_COMPLETE
	return true


func is_defeat() -> bool:
	return _players.filter(func(u): return u and u.is_alive).is_empty()


## ===== HUD 文本 =====

func get_status_text() -> String:
	match mission_type:
		TYPE_EXTRACT:
			return "目标：所有单位到达撤离区域"
		TYPE_DESTROY:
			return "目标：摧毁 %d 个目标 (%d/%d)" % [targets_required, targets_destroyed, targets_required]
		TYPE_ASSASSINATE:
			if boss_unit and is_instance_valid(boss_unit):
				return "目标：击杀 Boss %s" % boss_unit.unit_name
			return "目标：击杀敌方Boss"
		TYPE_ESCORT:
			if escort_vip and is_instance_valid(escort_vip):
				return "目标：护送 VIP %s 到撤离区域" % escort_vip.unit_name
			return "目标：护送单位到撤离区域"
		TYPE_STEAL_DATA:
			return "目标：激活 %d 个终端 (%d/%d) 后撤离至区域" % [terminals_required, terminals_activated, terminals_required]
		TYPE_INFILTRATE:
			match mission_stage:
				STAGE_APPROACH:
					return "阶段 1/3：接近并激活数据终端"
				STAGE_UPLOAD:
					var control := "控制稳定" if _has_upload_control() else "无人控制，上传暂停"
					return "阶段 2/3：上传数据 %d/%d（%s）" % [upload_progress, upload_turns_required, control]
				STAGE_EVACUATE:
					return "阶段 3/3：全员转移至西北撤离区域"
				_:
					return "任务完成"
		TYPE_DEFEND:
			return "目标：坚守 %d 回合 (当前 %d)" % [defend_turns_required, _turn_number]
		_:
			return "目标：消灭所有敌人"


## 获取当前关卡的特殊规则摘要（用于 HUD 显示）
func get_active_rules_summary() -> String:
	if special_rules.is_empty():
		return ""
	var parts: Array[String] = []
	for rule_id in special_rules.keys():
		var r = special_rules[rule_id]
		if bool(r.get("enabled", false)):
			parts.append(String(r.get("reason", rule_id)))
	return "；".join(parts)
