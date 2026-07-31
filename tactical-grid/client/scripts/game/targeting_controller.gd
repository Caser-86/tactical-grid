## 统一目标选择状态机
## 处理技能、物品、位置和单位目标的选择逻辑
## 支持范围高亮、有效性判断、确认和取消
extends Node
class_name TargetingController

## 目标选择开始时触发，UI 可据此显示提示
signal targeting_started(spec: Dictionary)
## 玩家确认目标后触发，携带统一格式的 target_data
signal target_confirmed(target_data: Dictionary)
## 玩家取消目标选择时触发
signal targeting_cancelled()

## 目标类型枚举（字符串常量，便于数据驱动）
const TARGET_SELF := "self"
const TARGET_ALLY := "ally"
const TARGET_ENEMY := "enemy"
const TARGET_POSITION := "position"
const TARGET_ANY_UNIT := "any_unit"

## 阵营过滤
const TEAM_ALLY := "ally"
const TEAM_ENEMY := "enemy"
const TEAM_ANY := "any"
const TEAM_SELF := "self"

## 当前是否处于目标选择模式
var is_active: bool = false

## 当前发起目标选择的单位
var _actor: Node = null
## 当前行动 ID（技能 ID 或物品 ID）
var _action_id: String = ""
## 当前行动类型："skill" / "item"
var _action_kind: String = ""
## 当前目标规格
var _spec: Dictionary = {}
## 上下文（地图、单位列表、视线回调等）
var _context: Dictionary = {}
## 当前合法目标格列表（缓存）
var _valid_cells_cache: Array[Vector2i] = []
## 当前合法目标单位列表（缓存）
var _valid_units_cache: Array = []

func _ready() -> void:
	pass

## 开始目标选择
## spec 必须包含：target_type, range, team_filter, requires_los, area_radius
## context 必须包含：map_width, map_height, players, enemies, los_check (Callable), blocked_check (Callable)
func begin(actor: Node, action_id: String, spec: Dictionary, context: Dictionary) -> void:
	if is_active:
		cancel()
	_actor = actor
	_action_id = action_id
	_spec = spec.duplicate(true)
	_context = context.duplicate(true)
	# 推断 action_kind：技能 ID 通常含 "_" 且不是物品 ID；显式传入更可靠
	_action_kind = String(spec.get("action_kind", "skill"))
	is_active = true
	_rebuild_valid_cache()
	targeting_started.emit(_spec)

## 获取当前所有合法目标格
func get_valid_cells() -> Array[Vector2i]:
	if not is_active:
		return []
	return _valid_cells_cache.duplicate()

## 获取当前所有合法目标单位
func get_valid_units() -> Array:
	if not is_active:
		return []
	return _valid_units_cache.duplicate()

## 尝试确认目标。成功返回 {success=true, target_data=...}，失败返回 {success=false, reason=...}
func try_confirm(cell: Vector2i) -> Dictionary:
	if not is_active:
		return {success = false, reason = "not_active"}
	if not _is_cell_in_bounds(cell):
		return {success = false, reason = "out_of_bounds"}
	if not _is_cell_valid(cell):
		return {success = false, reason = "invalid_cell"}
	var target_data := _build_target_data(cell)
	# CODE-CH1-010: 通过 query_action 获取预览，附加 cost/hit_chance 到 target_data
	_attach_query_preview(target_data)
	# 确认成功后清理状态（不触发 targeting_cancelled），然后触发 target_confirmed
	var data = target_data
	_clear_state()
	target_confirmed.emit(data)
	return {success = true, target_data = data}

## CODE-CH1-010: 若上下文提供 action_system，则通过 query_action 获取预览，
## 将 cost 和 hit_chance（若存在）附加到 target_data，使目标选择经过统一动作契约
func _attach_query_preview(target_data: Dictionary) -> void:
	var action_system = _context.get("action_system", null)
	if action_system == null:
		return
	var query_request := {
		"action": StringName(_action_kind),
		"unit": _actor,
		"action_id": _action_id,
	}
	if target_data.has("target_unit"):
		query_request["target"] = target_data["target_unit"]
	elif target_data.has("position"):
		query_request["target"] = target_data["position"]
	var preview = action_system.query_action(query_request)
	if not bool(preview.get("valid", false)):
		return
	if preview.has("cost"):
		target_data["cost"] = preview["cost"]
	if preview.has("hit_chance"):
		target_data["hit_chance"] = preview["hit_chance"]

## 取消目标选择
func cancel() -> void:
	if not is_active:
		return
	_clear_state()
	targeting_cancelled.emit()

## 清理内部状态（不触发任何信号）
func _clear_state() -> void:
	_actor = null
	_action_id = ""
	_action_kind = ""
	_spec.clear()
	_context.clear()
	_valid_cells_cache.clear()
	_valid_units_cache.clear()
	is_active = false

## 获取当前 actor
func get_actor() -> Node:
	return _actor

## 获取当前 action_id
func get_action_id() -> String:
	return _action_id

## 获取当前 action_kind
func get_action_kind() -> String:
	return _action_kind

## 获取当前 spec（只读副本）
func get_spec() -> Dictionary:
	return _spec.duplicate(true)

## ===== 内部实现 =====

## 重建合法目标缓存
func _rebuild_valid_cache() -> void:
	_valid_cells_cache.clear()
	_valid_units_cache.clear()
	if _actor == null or not _actor.is_alive:
		return
	var target_type = String(_spec.get("target_type", TARGET_SELF))
	match target_type:
		TARGET_SELF:
			# 自身目标：合法格就是 actor 所在格
			_valid_cells_cache.append(_actor.grid_pos)
			_valid_units_cache.append(_actor)
		TARGET_ALLY, TARGET_ENEMY, TARGET_ANY_UNIT:
			_populate_unit_targets(target_type)
		TARGET_POSITION:
			_populate_position_targets()
		_:
			push_warning("TargetingController: 未知 target_type=%s" % target_type)

## 填充单位目标
func _populate_unit_targets(target_type: String) -> void:
	var max_range = int(_spec.get("range", 1))
	var requires_los = bool(_spec.get("requires_los", true))
	var team_filter = String(_spec.get("team_filter", TEAM_ANY))
	var candidates: Array = []
	match team_filter:
		TEAM_ALLY:
			candidates = _context.get("players", [])
		TEAM_ENEMY:
			candidates = _context.get("enemies", [])
		TEAM_SELF:
			candidates = [_actor]
		TEAM_ANY, _:
			candidates = _context.get("players", []) + _context.get("enemies", [])
	for unit in candidates:
		if unit == null or not unit.is_alive:
			continue
		if unit == _actor and target_type != TARGET_SELF and team_filter != TEAM_SELF:
			# 友方/敌方/任意单位目标通常不包含自身（除非显式指定 TEAM_SELF）
			if target_type == TARGET_ENEMY:
				continue
			# TARGET_ALLY / TARGET_ANY_UNIT 允许自身作为目标（如医疗技能）
		var dist = GridSystem.manhattan_distance(_actor.grid_pos, unit.grid_pos)
		if dist > max_range:
			continue
		if requires_los and not _has_los(_actor.grid_pos, unit.grid_pos):
			continue
		_valid_units_cache.append(unit)
		if not _valid_cells_cache.has(unit.grid_pos):
			_valid_cells_cache.append(unit.grid_pos)

## 填充位置目标
func _populate_position_targets() -> void:
	var max_range = int(_spec.get("range", 1))
	var requires_los = bool(_spec.get("requires_los", false))
	var map_width = int(_context.get("map_width", 0))
	var map_height = int(_context.get("map_height", 0))
	if map_width <= 0 or map_height <= 0:
		return
	for y in range(map_height):
		for x in range(map_width):
			var cell = Vector2i(x, y)
			var dist = GridSystem.manhattan_distance(_actor.grid_pos, cell)
			if dist > max_range:
				continue
			if requires_los and not _has_los(_actor.grid_pos, cell):
				continue
			_valid_cells_cache.append(cell)

## 检查格子是否在地图边界内
func _is_cell_in_bounds(cell: Vector2i) -> bool:
	var map_width = int(_context.get("map_width", 0))
	var map_height = int(_context.get("map_height", 0))
	if map_width <= 0 or map_height <= 0:
		return false
	return cell.x >= 0 and cell.x < map_width and cell.y >= 0 and cell.y < map_height

## 检查格子是否为合法目标
func _is_cell_valid(cell: Vector2i) -> bool:
	return _valid_cells_cache.has(cell)

## 构建统一的 target_data 结构
func _build_target_data(cell: Vector2i) -> Dictionary:
	var data: Dictionary = {
		"position": cell,
		"action_id": _action_id,
		"action_kind": _action_kind,
		"actor": _actor,
	}
	# 附加目标单位（如果有）
	var unit_at = _find_unit_at(cell)
	if unit_at != null:
		data["target_unit"] = unit_at
	# 附加范围信息（如果 spec 指定了 area_radius）
	var area_radius = int(_spec.get("area_radius", 0))
	if area_radius > 0:
		data["area_radius"] = area_radius
		data["area_cells"] = _compute_area_cells(cell, area_radius)
	return data

## 查找指定格上的单位
func _find_unit_at(cell: Vector2i) -> Node:
	for unit in _valid_units_cache:
		if unit.grid_pos == cell:
			return unit
	# 也在全单位列表中查找（可能不在合法目标中，但仍可作为位置附着单位）
	for unit in _context.get("players", []) + _context.get("enemies", []):
		if unit and unit.is_alive and unit.grid_pos == cell:
			return unit
	return null

## 计算以 center 为中心、radius 为半径的所有格子
func _compute_area_cells(center: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var map_width = int(_context.get("map_width", 0))
	var map_height = int(_context.get("map_height", 0))
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cell = Vector2i(center.x + dx, center.y + dy)
			if cell.x < 0 or cell.y < 0:
				continue
			if map_width > 0 and cell.x >= map_width:
				continue
			if map_height > 0 and cell.y >= map_height:
				continue
			cells.append(cell)
	return cells

## 视线检查（委托给上下文提供的 los_check Callable）
func _has_los(from: Vector2i, to: Vector2i) -> bool:
	var los_check = _context.get("los_check", Callable())
	if los_check.is_valid():
		return bool(los_check.call(from, to))
	# 无视线检查器时默认有视线
	return true


## ===== 静态工具：从技能数据推断 spec =====

## 根据技能 ID 和技能数据推断目标选择规格
## 返回 {target_type, range, team_filter, requires_los, area_radius}
static func infer_skill_spec(skill_id: String, skill_data: Dictionary, caster: Node) -> Dictionary:
	# 先看显式 target 字段
	var explicit = String(skill_data.get("target", ""))
	if explicit != "":
		return _spec_from_explicit(explicit, skill_data, caster)
	# 根据技能 ID 推断
	return _spec_from_skill_id(skill_id, skill_data, caster)

## 根据物品数据推断目标选择规格
static func infer_item_spec(item_id: String, item_data: Dictionary, user: Node) -> Dictionary:
	var item_type = String(item_data.get("type", "consumable"))
	match item_type:
		"throwable":
			# 投掷物：位置目标，范围来自 effect.area
			var effect = item_data.get("effect", {})
			var area_str = String(effect.get("area", "1x1"))
			var area_radius = _parse_area_radius(area_str)
			# 默认投掷距离 5 格（可被物品数据 range 覆盖）
			var throw_range = int(item_data.get("range", 5))
			return {
				"target_type": TARGET_POSITION,
				"range": throw_range,
				"team_filter": TEAM_ANY,
				"requires_los": true,
				"area_radius": area_radius,
				"action_kind": "item",
			}
		"trap":
			# 陷阱：放置在自身所在格
			return {
				"target_type": TARGET_SELF,
				"range": 0,
				"team_filter": TEAM_SELF,
				"requires_los": false,
				"area_radius": 0,
				"action_kind": "item",
			}
		"consumable", _:
			# 消耗品：默认对自身或友方单体使用
			var effect = item_data.get("effect", {})
			# 复活针需要对倒地友方使用
			if effect.get("revive", false):
				return {
					"target_type": TARGET_ALLY,
					"range": 1,
					"team_filter": TEAM_ALLY,
					"requires_los": false,
					"area_radius": 0,
					"action_kind": "item",
				}
			# 默认自身
			return {
				"target_type": TARGET_SELF,
				"range": 0,
				"team_filter": TEAM_SELF,
				"requires_los": false,
				"area_radius": 0,
				"action_kind": "item",
			}

## 从显式 target 字段构建 spec
static func _spec_from_explicit(explicit: String, skill_data: Dictionary, caster: Node) -> Dictionary:
	var base := {
		"target_type": TARGET_SELF,
		"range": 0,
		"team_filter": TEAM_SELF,
		"requires_los": false,
		"area_radius": 0,
		"action_kind": "skill",
	}
	match explicit:
		"self":
			base.target_type = TARGET_SELF
			base.team_filter = TEAM_SELF
		"ally":
			base.target_type = TARGET_ALLY
			base.team_filter = TEAM_ALLY
			base.range = int(skill_data.get("range", 3))
			base.requires_los = bool(skill_data.get("requires_los", false))
		"enemy":
			base.target_type = TARGET_ENEMY
			base.team_filter = TEAM_ENEMY
			base.range = int(skill_data.get("range", _get_weapon_max_range(caster)))
			base.requires_los = true
		"position":
			base.target_type = TARGET_POSITION
			base.team_filter = TEAM_ANY
			base.range = int(skill_data.get("range", 5))
			base.requires_los = bool(skill_data.get("requires_los", true))
			base.area_radius = int(skill_data.get("area_radius", 0))
		"any_unit":
			base.target_type = TARGET_ANY_UNIT
			base.team_filter = TEAM_ANY
			base.range = int(skill_data.get("range", 3))
			base.requires_los = bool(skill_data.get("requires_los", false))
		_:
			base.target_type = TARGET_SELF
			base.team_filter = TEAM_SELF
	return base

## 根据技能 ID 模式推断 spec（无显式 target 字段时的回退）
static func _spec_from_skill_id(skill_id: String, skill_data: Dictionary, caster: Node) -> Dictionary:
	var base := {
		"target_type": TARGET_SELF,
		"range": 0,
		"team_filter": TEAM_SELF,
		"requires_los": false,
		"area_radius": 0,
		"action_kind": "skill",
	}
	# 根据技能 ID 前缀/后缀映射
	match skill_id:
		# 突击兵
		"asslt_dash_strike":
			base.target_type = TARGET_ENEMY
			base.team_filter = TEAM_ENEMY
			base.range = int(skill_data.get("range", 3))
			base.requires_los = true
		"asslt_breach":
			base.target_type = TARGET_POSITION
			base.team_filter = TEAM_ANY
			base.range = 1
			base.requires_los = false
			base.area_radius = 1
		"asslt_adrenaline":
			base.target_type = TARGET_SELF
			base.team_filter = TEAM_SELF
		"asslt_blink":
			base.target_type = TARGET_POSITION
			base.team_filter = TEAM_ANY
			base.range = 8
			base.requires_los = true
		# 狙击手
		"snip_precise":
			base.target_type = TARGET_ENEMY
			base.team_filter = TEAM_ENEMY
			base.range = _get_weapon_max_range(caster)
			base.requires_los = true
		"snip_overwatch", "snip_highground":
			base.target_type = TARGET_SELF
			base.team_filter = TEAM_SELF
		"snip_death_mark":
			base.target_type = TARGET_ENEMY
			base.team_filter = TEAM_ENEMY
			base.range = _get_weapon_max_range(caster)
			base.requires_los = true
		# 重装兵
		"heavy_suppress":
			base.target_type = TARGET_ENEMY
			base.team_filter = TEAM_ENEMY
			base.range = _get_weapon_max_range(caster)
			base.requires_los = true
		"heavy_grenade":
			base.target_type = TARGET_POSITION
			base.team_filter = TEAM_ANY
			base.range = 6
			base.requires_los = true
			base.area_radius = 1
		"heavy_taunt":
			base.target_type = TARGET_SELF
			base.team_filter = TEAM_SELF
		# 医疗兵
		"medic_heal":
			base.target_type = TARGET_ALLY
			base.team_filter = TEAM_ALLY
			base.range = 3
			base.requires_los = false
		"medic_revive":
			base.target_type = TARGET_ALLY
			base.team_filter = TEAM_ALLY
			base.range = 1
			base.requires_los = false
		"medic_adrenaline_shot":
			base.target_type = TARGET_ALLY
			base.team_filter = TEAM_ALLY
			base.range = 3
			base.requires_los = false
		"medic_area_heal":
			base.target_type = TARGET_POSITION
			base.team_filter = TEAM_ANY
			base.range = 4
			base.requires_los = false
			base.area_radius = 1
		# 侦察兵
		"scout_stealth":
			base.target_type = TARGET_SELF
			base.team_filter = TEAM_SELF
		"scout_scan":
			base.target_type = TARGET_POSITION
			base.team_filter = TEAM_ANY
			base.range = 6
			base.requires_los = false
			base.area_radius = 2
		"scout_mark":
			base.target_type = TARGET_ENEMY
			base.team_filter = TEAM_ENEMY
			base.range = _get_weapon_max_range(caster)
			base.requires_los = true
		"scout_trap":
			base.target_type = TARGET_SELF
			base.team_filter = TEAM_SELF
		# 通用
		"gen_overwatch":
			base.target_type = TARGET_SELF
			base.team_filter = TEAM_SELF
		"gen_hunker_down":
			base.target_type = TARGET_SELF
			base.team_filter = TEAM_SELF
		"gen_sprint":
			base.target_type = TARGET_SELF
			base.team_filter = TEAM_SELF
		# 被动技能不应进入目标选择（应在上游过滤）
		_:
			# 默认自身
			base.target_type = TARGET_SELF
			base.team_filter = TEAM_SELF
	return base

## 获取单位武器最大射程
static func _get_weapon_max_range(unit: Node) -> int:
	if unit == null:
		return 5
	var wr = unit.weapon_range
	if wr != null and wr.size() >= 2:
		return int(wr[1])
	return 5

## 解析 "NxN" 面积字符串为半径
static func _parse_area_radius(area_str: String) -> int:
	match area_str:
		"1x1":
			return 0
		"3x3":
			return 1
		"5x5":
			return 2
		"7x7":
			return 3
		_:
			var parts = area_str.split("x")
			if parts.size() == 2:
				var n = int(parts[0])
				return int(n / 2)
			return 0
