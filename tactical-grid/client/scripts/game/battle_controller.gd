## 战斗场景控制器
## 单一战斗状态源：管理地图、单位、回合、行动和渲染
extends Node2D
class_name BattleController

const CELL_SIZE = 64
const TutorialHintScene = preload("res://scenes/tutorial_hint.tscn")

## 待展示的教程 flag 队列（来自 level_config.tutorial_flags，跳过已读）
var _pending_tutorial_flags: Array[String] = []
## 当前活跃的教程提示实例
var _active_tutorial_hint: Control = null

## 渲染层
@onready var map_layer: Node2D = $MapLayer
@onready var move_highlight: Node2D = $MoveHighlightLayer
@onready var path_preview_layer: Node2D = $PathPreviewLayer
@onready var attack_highlight: Node2D = $AttackHighlightLayer
@onready var unit_layer: Node2D = $UnitLayer
@onready var effect_layer: Node2D = $EffectLayer
@onready var hud: HUD = $HUD
@onready var camera: Camera2D = $Camera2D

## 战斗状态
var map_data: Dictionary = {}
var map_width: int = 10
var map_height: int = 8
var level_id: String = ""
var level_config: Dictionary = {}

## 单位列表（单一状态源）
var player_units: Array = []
var enemy_units: Array = []

## 选择和交互状态
var selected_unit: Unit = null
var selected_action: String = ""  # "", "move", "attack", "skill", "item"
var reachable_cells: Dictionary = {}
var attack_targets: Array = []
var path_preview: Array[Vector2i] = []
# 技能/物品循环选择索引（配置驱动：每次按按钮切换到下一个）
var _skill_cycle_index: int = -1
var _item_cycle_index: int = -1

## 子系统
var turn_manager: TurnManager
var action_system: ActionSystem
var enemy_director: EnemyDirector
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## 胜利条件
var mission_type: String = "extract"
var evac_point: Vector2i = Vector2i(-1, -1)
var destructible_targets: Array[Vector2i] = []
var targets_destroyed: int = 0
var targets_required: int = 0

## 任务目标状态机：支持 destroy / steal_data / infiltrate / assassinate / escort / defend
## 可破坏目标：pos -> { "hp": int, "max_hp": int, "destroyed": bool }
var destructible_target_states: Dictionary = {}
## 终端列表：[Vector2i, ...]
var terminals: Array[Vector2i] = []
var terminals_activated: int = 0
var terminals_required: int = 0
## Boss 单位引用（assassinate 任务）
var boss_unit: Unit = null
## Boss 阶段状态（由 bosses.json 的 phases 驱动）
var boss_data: Dictionary = {}
var boss_phases: Array = []
var boss_current_phase: int = 0
var boss_max_hp_for_phase: int = 0
## Boss 专属能力运行时状态：ability_id -> { "counter": int, "last_turn": int }
var boss_ability_state: Dictionary = {}
## Boss 预警旗标：每个阶段是否已展示过预警
var boss_phase_warned: Array[bool] = []
## 护送 VIP 单位引用（escort 任务）
var escort_vip: Unit = null
## 防守任务回合限制（defend 任务）
var defend_turns_required: int = 0

## 战斗遥测数据（本场战斗累计）
## 记录攻击次数、命中、伤害、击杀等，用于平衡分析
var _telemetry: Dictionary = {}

## 初始化遥测字典
func _init_telemetry() -> void:
	_telemetry = {
		"level_id": level_id,
		"timestamp": Time.get_unix_time_from_system(),
		"shots_fired": 0,
		"shots_hit": 0,
		"shots_missed": 0,
		"critical_hits": 0,
		"damage_dealt": 0,        # 玩家对敌人造成的伤害
		"damage_taken": 0,        # 玩家承受的伤害
		"enemies_killed": 0,
		"players_lost": 0,
		"skills_used": 0,
		"items_used": 0,
		"overwatch_set": 0,
		"player_units": [],
		"enemy_units": [],
	}

## 记录一次攻击结果到遥测
func _record_attack_telemetry(attacker: Unit, target: Unit, hit: bool, damage: int, critical: bool) -> void:
	if attacker.team == "player":
		_telemetry.shots_fired += 1
		if hit:
			_telemetry.shots_hit += 1
			_telemetry.damage_dealt += damage
			if critical:
				_telemetry.critical_hits += 1
		else:
			_telemetry.shots_missed += 1
	else:
		# 敌人攻击玩家
		if hit:
			_telemetry.damage_taken += damage

## 记录单位死亡到遥测
func _record_death_telemetry(unit: Unit) -> void:
	if unit.team == "enemy":
		_telemetry.enemies_killed += 1
	else:
		_telemetry.players_lost += 1

## 记录技能使用到遥测
func _record_skill_telemetry() -> void:
	_telemetry.skills_used += 1

## 记录物品使用到遥测
func _record_item_telemetry() -> void:
	_telemetry.items_used += 1

## 记录警戒设置到遥测
func _record_overwatch_telemetry() -> void:
	_telemetry.overwatch_set += 1

## 收集单位摘要用于遥测
func _collect_unit_telemetry(units: Array, team: String) -> Array:
	var result = []
	for unit in units:
		result.append({
			"name": unit.unit_name,
			"job": unit.job,
			"team": team,
			"survived": unit.is_alive,
			"max_hp": unit.max_hp,
			"final_hp": unit.current_hp,
		})
	return result

## 完成遥测数据收集，附加到 battle_result
func _finalize_telemetry(battle_result: Dictionary) -> Dictionary:
	_telemetry.player_units = _collect_unit_telemetry(player_units, "player")
	_telemetry.enemy_units = _collect_unit_telemetry(enemy_units, "enemy")
	_telemetry.turns = battle_result.get("turns", 0)
	_telemetry.result = battle_result.get("result", "unknown")
	_telemetry.stars = battle_result.get("stars", 0)
	# 计算命中率
	if _telemetry.shots_fired > 0:
		_telemetry.hit_rate = float(_telemetry.shots_hit) / float(_telemetry.shots_fired)
	else:
		_telemetry.hit_rate = 0.0
	battle_result["telemetry"] = _telemetry.duplicate(true)
	return battle_result

## 颜色
const COLOR_MOVE = Color(0.13, 0.59, 0.95, 0.35)
const COLOR_ATTACK = Color(0.96, 0.26, 0.21, 0.35)
const COLOR_PATH = Color(0.0, 1.0, 0.0, 0.25)
const COLOR_EVAC = Color(0.0, 1.0, 0.0, 0.4)
const COLOR_TARGET = Color(1.0, 0.62, 0.0, 0.4)
const COLOR_TERMINAL = Color(0.0, 0.81, 0.82, 0.5)
const COLOR_SELECTED = Color(0.0, 1.0, 0.0, 0.3)

func _ready() -> void:
	rng.seed = hash(GameManager.current_level_id)
	level_id = GameManager.current_level_id
	level_config = CampaignRepository.get_level(level_id)
	_init_subsystems()
	_generate_map()
	_spawn_units()
	_setup_victory_conditions()
	_init_telemetry()
	_render_map()
	_render_units()
	# 先播放 intro 对话，结束后再开始战斗
	_play_intro_then_start()

## 退出场景树时释放未挂载的单位节点，避免资源泄漏
func _exit_tree() -> void:
	_cleanup_units()

## 释放所有单位节点（player_units 和 enemy_units 中的 Unit 实例）
## 这些 Unit 是 Node2D 但未添加到场景树，需要手动释放
func _cleanup_units() -> void:
	for unit in player_units:
		if unit and is_instance_valid(unit):
			unit.queue_free()
	for unit in enemy_units:
		if unit and is_instance_valid(unit):
			unit.queue_free()
	player_units.clear()
	enemy_units.clear()
	selected_unit = null
	boss_unit = null
	boss_data.clear()
	boss_phases.clear()
	boss_current_phase = 0
	boss_max_hp_for_phase = 0
	boss_ability_state.clear()
	boss_phase_warned.clear()
	escort_vip = null

func _play_intro_then_start() -> void:
	# 等待一帧确保场景树就绪
	await get_tree().process_frame
	var intro_id = level_config.get("intro_dialogue", "")
	if intro_id == "":
		_begin_tutorials_or_start()
		return
	GameManager.play_level_dialogue(level_id, "intro", Callable(self, "_begin_tutorials_or_start"))

## 进入战斗前依次展示未读教程 flag；全部展示完或被跳过后再启动战斗
func _begin_tutorials_or_start() -> void:
	_pending_tutorial_flags.clear()
	for f in level_config.get("tutorial_flags", []):
		_pending_tutorial_flags.append(String(f))
	_show_next_tutorial_or_start()

## 展示下一个未读教程；无剩余则启动战斗
func _show_next_tutorial_or_start() -> void:
	while _pending_tutorial_flags.size() > 0:
		var flag = _pending_tutorial_flags.pop_front()
		# 跳过已读教程
		if not TutorialHint.is_known(flag):
			_show_tutorial_flag(flag)
			return
	# 无待展示教程，启动战斗
	_start_battle()

## 展示单个教程提示；关闭后继续下一个或启动战斗
func _show_tutorial_flag(flag: String) -> void:
	# 清理上一个未关闭的教程实例
	if _active_tutorial_hint != null and is_instance_valid(_active_tutorial_hint):
		_active_tutorial_hint.queue_free()
	_active_tutorial_hint = TutorialHintScene.instantiate()
	add_child(_active_tutorial_hint)
	_active_tutorial_hint.show_hint(flag, Callable(self, "_on_tutorial_hint_closed"))

## 教程提示关闭回调：跳过按钮请求时直接启动战斗，否则继续下一个教程
func _on_tutorial_hint_closed() -> void:
	var skip_remaining = false
	if _active_tutorial_hint != null and is_instance_valid(_active_tutorial_hint):
		skip_remaining = _active_tutorial_hint.is_skip_requested()
		_active_tutorial_hint.queue_free()
		_active_tutorial_hint = null
	if skip_remaining:
		_pending_tutorial_flags.clear()
		_start_battle()
	else:
		_show_next_tutorial_or_start()

func _init_subsystems() -> void:
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	turn_manager.set_victory_check(_check_victory)
	turn_manager.set_defeat_check(_check_defeat)
	turn_manager.turn_phase_changed.connect(_on_phase_changed)
	turn_manager.battle_won.connect(_on_battle_won)
	turn_manager.battle_lost.connect(_on_battle_lost)

	action_system = ActionSystem.new()
	add_child(action_system)

	enemy_director = EnemyDirector.new()
	add_child(enemy_director)

## 生成战斗地图：优先加载锁定地图，失败时回退到运行时生成。
## 锁定地图是服务端生成并版本锁定的正式关卡数据，保证每关地形、出生点和实体一致。
func _generate_map() -> void:
	var loaded := _load_locked_map(level_id)
	if loaded.is_empty():
		_generate_runtime_map()
		return
	# 应用锁定地图数据
	map_data = loaded
	map_width = int(map_data.size.width)
	map_height = int(map_data.size.height)
	mission_type = map_data.get("mission_type", level_config.get("mission_type", "extract"))
	# 从 objects 中提取撤离点与可破坏目标，统一到运行时状态
	_extract_objectives_from_map()
	action_system.set_map_data(map_data)
	GameManager.current_map_data = map_data

## 加载锁定地图 JSON。成功返回归一化后的 map_data 字典，失败返回空字典。
func _load_locked_map(lid: String) -> Dictionary:
	var res := MapLoader.load_locked_map(lid)
	if not res.get("ok", false):
		_log("锁定地图加载失败 (%s): %s，回退到运行时生成" % [lid, res.get("error", "unknown")])
		return {}
	var data: Dictionary = res.get("data", {})
	# 基本完整性校验：必须有 layers 和尺寸
	var layers = data.get("layers", {})
	var base = layers.get("base_terrain", [])
	if base.is_empty():
		_log("锁定地图 %s 缺少 base_terrain，回退到运行时生成" % lid)
		return {}
	return data

## 从 map_data.objects 中提取撤离点和可破坏目标，写入运行时状态。
## 保证锁定地图中的 evac / destructible_target / terminal 与 victory 检查一致。
func _extract_objectives_from_map() -> void:
	destructible_targets.clear()
	destructible_target_states.clear()
	targets_destroyed = 0
	targets_required = 0
	terminals.clear()
	terminals_activated = 0
	terminals_required = 0
	evac_point = Vector2i(-1, -1)
	for obj in map_data.get("objects", []):
		var t = obj.get("type", "")
		if t == "evac":
			evac_point = Vector2i(int(obj.x), int(obj.y))
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
	# destroy 任务所需数量取自 objects 中实际目标数，最少 1
	if mission_type == "destroy":
		targets_required = max(destructible_targets.size(), 1)
	# steal_data / infiltrate 需要激活所有终端
	if mission_type in ["steal_data", "infiltrate"]:
		terminals_required = terminals.size()
	# defend 任务：使用 level_config 的 max_turns 或默认 10
	if mission_type == "defend":
		defend_turns_required = int(level_config.get("max_turns", 10))

## 运行时程序化生成地图（开发回退路径，不依赖锁定地图）
func _generate_runtime_map() -> void:
	var seed_val = int(level_config.get("seed", 1001))
	var size_str = level_config.get("size", "small")
	var theme = level_config.get("theme", "warehouse")

	match size_str:
		"small": map_width = 10; map_height = 8
		"medium": map_width = 14; map_height = 10
		"large": map_width = 18; map_height = 12
		_: map_width = 10; map_height = 8

	mission_type = level_config.get("mission_type", "extract")

	var gen_rng = RandomNumberGenerator.new()
	gen_rng.seed = seed_val

	var base_terrain: Array = []
	var blocker: Array = []
	var height_layer: Array = []

	for y in range(map_height):
		var row_t: Array = []
		var row_b: Array = []
		var row_h: Array = []
		for x in range(map_width):
			var r = gen_rng.randf()
			var t = 0  # plain
			if r < 0.08:
				t = 2  # forest
			elif r < 0.12:
				t = 4  # highland
			elif r < 0.15:
				t = 3  # sand
			elif r < 0.17:
				t = 5  # water
			row_t.append(t)
			row_h.append(1 if t == 4 else 0)

			var b = 0
			var rb = gen_rng.randf()
			if rb < 0.08:
				b = 6  # wall
			elif rb < 0.14:
				b = 7  # crate
			row_b.append(b)
		base_terrain.append(row_t)
		blocker.append(row_b)
		height_layer.append(row_h)

	# 确保出生点区域开阔
	_clear_area(base_terrain, blocker, 0, 0, 3, 3)
	_clear_area(base_terrain, blocker, map_width - 4, map_height - 4, 3, 3)

	var player_spawns = [
		{"type": "spawn_player", "x": 1, "y": 1},
		{"type": "spawn_player", "x": 1, "y": 2},
		{"type": "spawn_player", "x": 2, "y": 1},
		{"type": "spawn_player", "x": 0, "y": 2},
	]

	var enemy_spawns = []
	var enemy_count = int(level_config.get("enemy_count", 5))
	for i in range(enemy_count):
		var ex = map_width - 2 - (i % 3)
		var ey = map_height - 2 - (i / 3)
		enemy_spawns.append({"type": "spawn_enemy", "x": ex, "y": ey, "job": _pick_enemy_type(gen_rng)})

	var objects: Array = []
	objects.append_array(player_spawns)
	objects.append_array(enemy_spawns)

	# 撤离点
	if mission_type == "extract" or mission_type == "steal_data":
		evac_point = Vector2i(map_width - 2, map_height - 2)
		_clear_cell(base_terrain, blocker, evac_point.x, evac_point.y)
		objects.append({"type": "evac", "x": evac_point.x, "y": evac_point.y})

	# 可破坏目标
	if mission_type == "destroy":
		targets_required = 3
		for i in range(targets_required):
			var tx = 2 + gen_rng.randi_range(0, map_width - 4)
			var ty = 2 + gen_rng.randi_range(0, map_height - 4)
			var tpos = Vector2i(tx, ty)
			if not tpos in destructible_targets:
				destructible_targets.append(tpos)
				objects.append({"type": "destructible_target", "x": tx, "y": ty})

	map_data = {
		"map_id": level_id,
		"seed": seed_val,
		"size": {"width": map_width, "height": map_height},
		"theme": theme,
		"mission_type": mission_type,
		"layers": {
			"base_terrain": base_terrain,
			"blocker": blocker,
			"height": height_layer,
		},
		"objects": objects,
		"scripts": [],
		"victory": {"type": mission_type},
	}

	action_system.set_map_data(map_data)
	GameManager.current_map_data = map_data

func _clear_area(terrain: Array, blocker: Array, x0: int, y0: int, w: int, h: int) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			if y >= 0 and y < terrain.size() and x >= 0 and x < terrain[y].size():
				terrain[y][x] = 0
				blocker[y][x] = 0

func _clear_cell(terrain: Array, blocker: Array, x: int, y: int) -> void:
	if y >= 0 and y < terrain.size() and x >= 0 and x < terrain[y].size():
		terrain[y][x] = 0
		blocker[y][x] = 0

func _pick_enemy_type(gen_rng: RandomNumberGenerator) -> String:
	var chapter = int(level_config.get("chapter", 1))
	var pool: Array = ["sentry_basic", "drone_scout"]
	if chapter >= 2:
		pool.append_array(["sentry_elite", "sentry_sniper", "drone_assault"])
	if chapter >= 3:
		pool.append_array(["shield_bot", "heavy_gunner", "drone_bomber"])
	if chapter >= 4:
		pool.append_array(["stealth_assassin", "flame_trooper", "elite_guard"])
	return pool[gen_rng.randi() % pool.size()]

func _spawn_units() -> void:
	var player_count = int(level_config.get("player_units", 3))

	# 从 GameManager 队伍创建战斗单位（应用等级、装备、属性成长）
	var roster = GameManager.get_roster()
	var roster_units = []
	if not roster.is_empty():
		roster_units = GameManager.create_battle_units_from_roster()

	# 如果存档没有角色，回退到默认创建
	if roster_units.is_empty():
		var jobs = ["assault", "sniper", "heavy", "medic", "scout"]
		for i in range(player_count):
			var job = jobs[i % jobs.size()]
			roster_units.append(GameData.create_player_unit(job, _get_job_display_name(job)))

	for obj in map_data.objects:
		if obj.type == "spawn_player" and player_units.size() < player_count:
			var idx = player_units.size()
			var unit: Unit
			if idx < roster_units.size():
				unit = roster_units[idx]
			else:
				unit = GameData.create_player_unit("assault", _get_job_display_name("assault"))
			unit.grid_pos = Vector2i(obj.x, obj.y)
			unit.height = MapLoader.get_height_at(map_data, obj.x, obj.y)
			player_units.append(unit)

		elif obj.type == "spawn_enemy":
			var enemy_type = obj.get("job", "sentry_basic")
			var unit = GameData.create_enemy_unit(enemy_type)
			unit.grid_pos = Vector2i(obj.x, obj.y)
			unit.height = MapLoader.get_height_at(map_data, obj.x, obj.y)
			_apply_difficulty_to_enemy(unit)
			enemy_units.append(unit)

	# 根据任务类型标记特殊单位（Boss / VIP）
	_designate_special_units()

## 根据任务类型标记 Boss 单位（assassinate）和 VIP 单位（escort）。
## Boss 从 levels.json 的 boss_id 字段创建；若无则取第一个敌人作为 Boss。
## VIP 取第一个玩家单位。
func _designate_special_units() -> void:
	boss_unit = null
	escort_vip = null
	if mission_type == "assassinate":
		var boss_id = level_config.get("boss_id", "")
		if boss_id != "":
			var boss_data = GameData.get_boss(boss_id)
			if not boss_data.is_empty():
				# 用 Boss 数据强化第一个敌人单位
				if not enemy_units.is_empty():
					var boss = enemy_units[0]
					_apply_boss_stats(boss, boss_data)
					boss_unit = boss
					_log("Boss 已就位：%s" % boss_data.get("name", boss_id))
				else:
					# 没有敌人时直接创建 Boss
					var boss = GameData.create_enemy_unit("elite_guard")
					_apply_boss_stats(boss, boss_data)
					# 放在地图右上角
					boss.grid_pos = Vector2i(map_width - 2, 1)
					boss.height = MapLoader.get_height_at(map_data, boss.grid_pos.x, boss.grid_pos.y)
					enemy_units.append(boss)
					boss_unit = boss
					_log("Boss 已生成：%s" % boss_data.get("name", boss_id))
		elif not enemy_units.is_empty():
			# 无 boss_id 时，将第一个敌人标记为 Boss
			boss_unit = enemy_units[0]
			boss_unit.unit_name = boss_unit.unit_name + " [Boss]"
			_log("Boss 已指定：%s" % boss_unit.unit_name)
	elif mission_type == "escort":
		# 护送任务：第一个玩家单位是 VIP
		if not player_units.is_empty():
			escort_vip = player_units[0]
			escort_vip.unit_name = escort_vip.unit_name + " [VIP]"
			_log("VIP 已指定：%s" % escort_vip.unit_name)

## 应用 Boss 数据到单位（强化 HP/护甲/属性），并初始化阶段状态
func _apply_boss_stats(unit: Unit, bdata: Dictionary) -> void:
	var hp = int(bdata.get("hp", unit.max_hp))
	unit.max_hp = hp
	unit.current_hp = hp
	unit.armor = int(bdata.get("armor", unit.armor))
	var boss_name = bdata.get("name", "Boss")
	unit.unit_name = boss_name
	# 初始化 Boss 阶段状态
	boss_data = bdata.duplicate(true)
	boss_phases = bdata.get("phases", [])
	boss_current_phase = 0
	boss_max_hp_for_phase = hp
	boss_ability_state.clear()
	boss_phase_warned.clear()
	boss_phase_warned.resize(boss_phases.size())
	for i in range(boss_phase_warned.size()):
		boss_phase_warned[i] = false
	# 应用第 0 阶段的武器/能力
	if not boss_phases.is_empty():
		_apply_boss_phase(unit, 0)

## 应用 Boss 指定阶段的武器、能力和狂暴效果
func _apply_boss_phase(unit: Unit, phase_idx: int) -> void:
	if phase_idx < 0 or phase_idx >= boss_phases.size():
		return
	var phase = boss_phases[phase_idx]
	# 应用武器（取阶段武器列表中的第一个作为主武器）
	var weapons = phase.get("weapons", [])
	if not weapons.is_empty():
		_apply_boss_weapon(unit, weapons[0])
	# 初始化该阶段的能力状态
	var abilities = phase.get("abilities", [])
	for ability_id in abilities:
		if not boss_ability_state.has(ability_id):
			boss_ability_state[ability_id] = {
				"counter": 0,
				"last_turn": -1,
			}
	# 应用狂暴效果
	var enrage = phase.get("enrage", "")
	_apply_boss_enrage(unit, enrage)
	boss_current_phase = phase_idx

## 从武器 ID 解析并应用 Boss 武器属性
## 优先从 GameData 查找；若不存在，则从 ID 模式解析（如 laser_array_2_8 → range [2,8]）
func _apply_boss_weapon(unit: Unit, weapon_id: String) -> void:
	var wdata = GameData.get_weapon(weapon_id)
	if not wdata.is_empty():
		unit.weapon_range = wdata.get("range", unit.weapon_range)
		unit.weapon_damage = wdata.get("damage", unit.weapon_damage)
		unit.weapon_optimal_range = (unit.weapon_range[0] + unit.weapon_range[1]) / 2
		unit.weapon_special = wdata.get("special", "")
		return
	# 回退：从 ID 解析范围数字
	var nums = []
	var parts = weapon_id.split("_")
	for p in parts:
		if p.is_valid_int():
			nums.append(int(p))
	if nums.size() >= 2:
		unit.weapon_range = [nums[0], nums[1]]
		unit.weapon_optimal_range = (nums[0] + nums[1]) / 2
	# 解析特殊效果
	if weapon_id.find("aoe") >= 0:
		unit.weapon_special = "aoe_3x3_destroy_cover"
	elif weapon_id.find("silenced") >= 0:
		unit.weapon_special = "silent_ignore_armor"
	elif weapon_id.find("pierce") >= 0:
		unit.weapon_special = "pierce_50_ignore_half_cover"

## 应用 Boss 狂暴效果
func _apply_boss_enrage(unit: Unit, enrage: String) -> void:
	match enrage:
		"attack_plus_50":
			# 伤害提升 50%（基于当前武器伤害）
			if unit.weapon_damage.size() >= 2:
				unit.weapon_damage[0] = int(round(unit.weapon_damage[0] * 1.5))
				unit.weapon_damage[1] = int(round(unit.weapon_damage[1] * 1.5))
		"move_plus_2":
			unit.base_move_points += 2
			unit.move_points = unit.base_move_points
		"move_plus_1":
			unit.base_move_points += 1
			unit.move_points = unit.base_move_points
		"":
			pass
		_:
			_log("Boss 狂暴效果未实现：%s" % enrage)

## 检查 Boss 是否需要切换阶段（在 Boss 受伤时调用）
func _check_boss_phase_transition(unit: Unit) -> void:
	if boss_phases.is_empty() or unit != boss_unit or not unit.is_alive:
		return
	var hp_ratio = float(unit.current_hp) / float(boss_max_hp_for_phase)
	# 查找应该处于的阶段：HP 比率 >= 阶段阈值的最高阶段
	var target_phase = boss_current_phase
	for i in range(boss_phases.size()):
		var threshold = float(boss_phases[i].get("hp_threshold", 1.0))
		if hp_ratio >= threshold:
			target_phase = i
			break
	# 如果阶段提升（HP 下降触发更高阶段索引）
	if target_phase > boss_current_phase:
		_show_boss_phase_warning(target_phase)
		_apply_boss_phase(unit, target_phase)

## 展示 Boss 阶段切换预警
func _show_boss_phase_warning(new_phase_idx: int) -> void:
	if new_phase_idx < 0 or new_phase_idx >= boss_phases.size():
		return
	if boss_phase_warned[new_phase_idx]:
		return
	boss_phase_warned[new_phase_idx] = true
	var phase = boss_phases[new_phase_idx]
	var phase_name = phase.get("name", "阶段%d" % (new_phase_idx + 1))
	var abilities = phase.get("abilities", [])
	var enrage = phase.get("enrage", "")
	# 构建预警文本
	var warning_lines = ["⚠ Boss 阶段切换：%s 进入「%s」！" % [boss_data.get("name", "Boss"), phase_name]]
	if not abilities.is_empty():
		var ability_desc = _describe_boss_abilities(abilities)
		warning_lines.append("新能力：%s" % ability_desc)
	if enrage != "":
		warning_lines.append("狂暴效果：%s" % _describe_boss_enrage(enrage))
	for line in warning_lines:
		_log(line)
	# 更新目标显示
	if hud:
		hud.update_objective(_get_objective_text())

## 生成 Boss 能力描述文本
func _describe_boss_abilities(abilities: Array) -> String:
	var descs = []
	for ab in abilities:
		descs.append(_describe_boss_ability(ab))
	return ", ".join(descs)

## 描述单个 Boss 能力
func _describe_boss_ability(ability_id: String) -> String:
	match ability_id:
		"summon_drone_every_3":
			return "每3回合召唤无人机"
		"summon_drone_every_2":
			return "每2回合召唤无人机"
		"summon_heavy_gunner":
			return "召唤重机枪手"
		"summon_clone_1", "summon_clone_2":
			return "生成分身"
		"shield_regen_20":
			return "每回合恢复20护盾"
		"shield_regen_30":
			return "每回合恢复30护盾"
		"stealth_every_3":
			return "每3回合潜行"
		"stealth_every_2":
			return "每2回合潜行"
		"permanent_stealth":
			return "永久潜行"
		"place_trap":
			return "放置陷阱"
		"teleport_every_turn":
			return "每回合传送"
		"heal_self_30":
			return "自我治疗30"
		"taunt":
			return "嘲讽"
		"suppress_area":
			return "区域压制"
		_:
			return ability_id

## 描述 Boss 狂暴效果
func _describe_boss_enrage(enrage: String) -> String:
	match enrage:
		"attack_plus_50":
			return "攻击力+50%"
		"move_plus_2":
			return "移动+2"
		"move_plus_1":
			return "移动+1"
		"clone_death_attack_plus_10":
			return "分身死亡时攻击+10"
		"enrage_plus_1_ap":
			return "行动点+1"
		_:
			return enrage

## 在敌人回合开始时处理 Boss 专属能力
func _process_boss_abilities() -> void:
	if boss_unit == null or not boss_unit.is_alive or boss_phases.is_empty():
		return
	if boss_current_phase < 0 or boss_current_phase >= boss_phases.size():
		return
	var phase = boss_phases[boss_current_phase]
	var abilities = phase.get("abilities", [])
	var current_turn = turn_manager.turn_number
	for ability_id in abilities:
		_execute_boss_ability(ability_id, current_turn)

## 执行单个 Boss 能力
func _execute_boss_ability(ability_id: String, current_turn: int) -> void:
	var state = boss_ability_state.get(ability_id, {"counter": 0, "last_turn": -1})
	state.counter += 1
	state.last_turn = current_turn
	boss_ability_state[ability_id] = state
	match ability_id:
		"summon_drone_every_3":
			if state.counter % 3 == 0:
				_boss_summon_unit("drone_scout", "无人机")
		"summon_drone_every_2":
			if state.counter % 2 == 0:
				_boss_summon_unit("drone_scout", "无人机")
		"summon_heavy_gunner":
			if state.counter == 1:
				_boss_summon_unit("heavy_gunner", "重机枪手")
		"shield_regen_20":
			_boss_regen_shield(20)
		"shield_regen_30":
			_boss_regen_shield(30)
		"heal_self_30":
			if state.counter == 1:
				boss_unit.heal(30)
				_log("Boss %s 自我治疗 30 HP" % boss_unit.unit_name)
		"stealth_every_3":
			if state.counter % 3 == 0:
				boss_unit.add_status("stealth", 2)
				_log("Boss %s 进入潜行" % boss_unit.unit_name)
		"stealth_every_2":
			if state.counter % 2 == 0:
				boss_unit.add_status("stealth", 2)
				_log("Boss %s 进入潜行" % boss_unit.unit_name)
		"permanent_stealth":
			if not boss_unit.has_status("stealth"):
				boss_unit.add_status("stealth", 99)
				_log("Boss %s 永久潜行" % boss_unit.unit_name)
		_:
			pass

## Boss 召唤增援单位
func _boss_summon_unit(enemy_type: String, display_name: String) -> void:
	if enemy_director:
		var alive_e = 0
		for u in enemy_units:
			if u and u.is_alive:
				alive_e += 1
		if alive_e >= enemy_director.enemy_cap_per_wave:
			_log("Boss 召唤失败：已达单位上限")
			return
	var spawn_pos = _find_reinforcement_spawn()
	if spawn_pos.x < 0:
		_log("Boss 召唤失败：无可用出生点")
		return
	var unit = GameData.create_enemy_unit(enemy_type)
	if unit == null:
		return
	unit.grid_pos = spawn_pos
	unit.height = MapLoader.get_height_at(map_data, spawn_pos.x, spawn_pos.y)
	_apply_difficulty_to_enemy(unit)
	enemy_units.append(unit)
	_create_unit_sprite(unit)
	_log("Boss 召唤了 %s (%d,%d)" % [display_name, spawn_pos.x, spawn_pos.y])

## Boss 恢复护盾（护盾作为临时 HP 吸收层，简化为直接治疗上限的一部分）
func _boss_regen_shield(amount: int) -> void:
	if boss_unit and boss_unit.is_alive:
		# 护盾作为临时护甲层处理：恢复护甲到一定上限
		var armor_cap = int(boss_data.get("armor", 0)) + amount
		boss_unit.armor = mini(boss_unit.armor + amount, armor_cap)
		_log("Boss %s 恢复 %d 护盾（当前护甲 %d）" % [boss_unit.unit_name, amount, boss_unit.armor])

## 应用难度调整到敌人单位（仅 HP/伤害，不修改命中率）
## 故事难度弱化敌人，困难难度强化敌人
func _apply_difficulty_to_enemy(unit: Unit) -> void:
	var params = GameManager.get_difficulty_params()
	var hp_mult = float(params.get("enemy_hp_multiplier", 1.0))
	var dmg_mult = float(params.get("enemy_damage_multiplier", 1.0))
	if hp_mult != 1.0:
		var new_max = int(round(unit.max_hp * hp_mult))
		unit.current_hp = new_max
		unit.max_hp = new_max
	if dmg_mult != 1.0:
		# 武器伤害是 [min, max] 数组
		if unit.weapon_damage.size() >= 2:
			unit.weapon_damage[0] = int(round(unit.weapon_damage[0] * dmg_mult))
			unit.weapon_damage[1] = int(round(unit.weapon_damage[1] * dmg_mult))

func _get_job_display_name(job: String) -> String:
	var job_info = GameData.get_job(job)
	return job_info.get("name", job)

func _setup_victory_conditions() -> void:
	# defend 任务使用 level_config 的 max_turns；其他默认 20
	if mission_type == "defend":
		turn_manager.max_turns = int(level_config.get("max_turns", 10))
	else:
		turn_manager.max_turns = 20
	# 胜利和失败检查通过 Callable 设置

## ===== 渲染 =====

func _render_map() -> void:
	# 清除旧渲染
	for child in map_layer.get_children():
		child.queue_free()

	var base_terrain = map_data.layers.base_terrain
	var blocker = map_data.layers.blocker

	for y in range(map_height):
		for x in range(map_width):
			var terrain = base_terrain[y][x]
			var color = GameTheme.get_terrain_color(terrain)
			_draw_cell_on(map_layer, Vector2i(x, y), color)

			var block = blocker[y][x]
			if block != 0:
				_draw_cell_on(map_layer, Vector2i(x, y), GameTheme.get_terrain_color(block))

	# 标记撤离点、目标和终端
	for obj in map_data.objects:
		if obj.type == "evac":
			_draw_cell_on(map_layer, Vector2i(obj.x, obj.y), COLOR_EVAC)
		elif obj.type == "destructible_target":
			_draw_cell_on(map_layer, Vector2i(obj.x, obj.y), COLOR_TARGET)
		elif obj.type == "terminal":
			_draw_cell_on(map_layer, Vector2i(obj.x, obj.y), COLOR_TERMINAL)

	# 调整相机
	camera.position = Vector2(map_width * CELL_SIZE / 2.0, map_height * CELL_SIZE / 2.0)

func _render_units() -> void:
	for child in unit_layer.get_children():
		child.queue_free()

	for unit in player_units:
		_create_unit_sprite(unit)

	for unit in enemy_units:
		_create_unit_sprite(unit)

func _create_unit_sprite(unit: Unit) -> void:
	var sprite = UnitSprite.new()
	sprite.update_unit(unit)
	sprite.position = GridSystem.grid_to_world(unit.grid_pos)
	unit_layer.add_child(sprite)
	unit.ap_changed.connect(_on_unit_ap_changed)
	unit.unit_died.connect(_on_unit_died)
	unit.unit_damaged.connect(_on_unit_damaged)

func _draw_cell_on(layer: Node2D, pos: Vector2i, color: Color) -> void:
	var rect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(CELL_SIZE, CELL_SIZE)
	rect.position = GridSystem.grid_to_world(pos)
	layer.add_child(rect)

func _highlight_cell(layer: Node2D, pos: Vector2i, color: Color) -> void:
	var rect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
	rect.position = GridSystem.grid_to_world(pos) + Vector2(1, 1)
	layer.add_child(rect)

func _clear_layer(layer: Node2D) -> void:
	for child in layer.get_children():
		child.queue_free()

## ===== 战斗流程 =====

func _start_battle() -> void:
	# 应用难度回合限制加成（故事难度+5回合，困难难度-3回合）
	var diff_params = GameManager.get_difficulty_params()
	var turn_limit = 20 + int(diff_params.get("turn_limit_bonus", 0))
	turn_limit = max(5, turn_limit)  # 最低 5 回合
	turn_manager.setup(player_units, enemy_units, turn_limit)
	action_system.set_units(player_units, enemy_units)
	enemy_director.setup(map_data.get("scripts", []))
	# 根据关卡配置设置增援上限（防止无限刷怪）
	enemy_director.max_reinforcements = int(level_config.get("max_reinforcements", 20))
	enemy_director.enemy_cap_per_wave = int(level_config.get("enemy_cap", 12))
	hud.set_battle_controller(self)
	turn_manager.start_battle()
	hud.update_objective(_get_objective_text())
	hud.update_turn_display(1, TurnManager.TurnPhase.PLAYER_ACTION)
	_log("战斗开始！难度=%s 回合上限=%d" % [GameManager.get_settings().get("difficulty", "standard"), turn_limit])

func _get_objective_text() -> String:
	match mission_type:
		"extract": return "目标：所有单位到达撤离点"
		"destroy": return "目标：摧毁 %d 个目标 (%d/%d)" % [targets_required, targets_destroyed, targets_required]
		"assassinate":
			if boss_unit:
				return "目标：击杀 Boss %s" % boss_unit.unit_name
			return "目标：击杀敌方Boss"
		"escort":
			if escort_vip:
				return "目标：护送 VIP %s 到撤离点" % escort_vip.unit_name
			return "目标：护送单位到撤离点"
		"steal_data", "infiltrate":
			return "目标：激活 %d 个终端 (%d/%d) 后撤离" % [terminals_required, terminals_activated, terminals_required]
		"defend":
			return "目标：坚守 %d 回合 (当前 %d)" % [defend_turns_required, turn_manager.turn_number]
		_: return "目标：消灭所有敌人"

func _check_victory() -> bool:
	match mission_type:
		"extract":
			return _check_extract_victory()
		"destroy":
			return targets_destroyed >= targets_required and targets_required > 0
		"assassinate":
			return _check_assassinate_victory()
		"escort":
			return _check_escort_victory()
		"steal_data", "infiltrate":
			return _check_data_victory()
		"defend":
			return _check_defend_victory()
		_:
			# 默认歼灭
			return enemy_units.filter(func(u): return u.is_alive).is_empty()

## 撤离模式：所有存活玩家单位到达撤离点
func _check_extract_victory() -> bool:
	if evac_point.x < 0:
		return false
	var alive_players = player_units.filter(func(u): return u.is_alive)
	if alive_players.is_empty():
		return false
	for u in alive_players:
		if u.grid_pos != evac_point:
			return false
	return true

## 暗杀模式：Boss 单位死亡
func _check_assassinate_victory() -> bool:
	if boss_unit:
		return not boss_unit.is_alive
	# 无 Boss 指定时退化为歼灭
	return enemy_units.filter(func(u): return u.is_alive).is_empty()

## 护送模式：VIP 存活且到达撤离点
func _check_escort_victory() -> bool:
	if evac_point.x < 0:
		return false
	if escort_vip == null or not escort_vip.is_alive:
		return false
	return escort_vip.grid_pos == evac_point

## 窃取数据/潜入：先激活所有终端，再撤离
func _check_data_victory() -> bool:
	if evac_point.x < 0:
		return false
	# 必须先激活所有终端
	if terminals_activated < terminals_required:
		return false
	var alive_players = player_units.filter(func(u): return u.is_alive)
	if alive_players.is_empty():
		return false
	for u in alive_players:
		if u.grid_pos != evac_point:
			return false
	return true

## 防守模式：存活到指定回合数
func _check_defend_victory() -> bool:
	if defend_turns_required <= 0:
		return false
	return turn_manager.turn_number >= defend_turns_required

func _check_defeat() -> bool:
	# 所有玩家单位死亡
	return player_units.filter(func(u): return u.is_alive).is_empty()

## ===== 回合回调 =====

func _on_phase_changed(phase: TurnManager.TurnPhase) -> void:
	match phase:
		TurnManager.TurnPhase.PLAYER_ACTION:
			hud.update_turn_display(turn_manager.turn_number, phase)
			turn_manager.input_locked = false
			hud.set_buttons_disabled(false)
			hud.update_objective(_get_objective_text())
			_log("第 %d 回合 - 玩家行动" % turn_manager.turn_number)

		TurnManager.TurnPhase.ENEMY_ACTION:
			hud.update_turn_display(turn_manager.turn_number, phase)
			turn_manager.input_locked = true
			hud.set_buttons_disabled(true)
			_log("第 %d 回合 - 敌人行动" % turn_manager.turn_number)
			# 敌人回合开始时检查增援触发
			_process_reinforcements(turn_manager.turn_number)
			_run_enemy_turn()

		TurnManager.TurnPhase.BATTLE_OVER:
			turn_manager.input_locked = true
			hud.set_buttons_disabled(true)

## 每回合处理增援触发：更新存活计数，检查触发器，生成增援单位
func _process_reinforcements(turn_number: int) -> void:
	if not enemy_director:
		return
	# 更新存活单位计数（用于上限控制）
	var alive_p = 0
	var alive_e = 0
	for u in player_units:
		if u and u.is_alive:
			alive_p += 1
	for u in enemy_units:
		if u and u.is_alive:
			alive_e += 1
	enemy_director.set_alive_counts(alive_p, alive_e)
	# 检查增援触发
	var spawned_waves = enemy_director.on_turn_start(turn_number)
	for wave in spawned_waves:
		var units_data = wave.get("units", [])
		var msg = wave.get("message", "")
		_spawn_reinforcement_units(units_data)
		if msg != "":
			_log(msg)
	# 同步 action_system 的单位列表（增援可能已加入）
	action_system.set_units(player_units, enemy_units)

## 实际生成增援敌人单位并加入战斗
## 出生点选择：优先使用脚本中指定的 position，否则在地图边缘找空位
func _spawn_reinforcement_units(units_data: Array) -> void:
	for unit_data in units_data:
		var enemy_type = unit_data.get("type", "sentry_basic")
		var pos_arr = unit_data.get("position", [0, 0])
		var spawn_pos = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
		# 若指定位置被占或越界，在地图边缘找空位
		if not GridSystem.is_in_bounds(spawn_pos, map_width, map_height) or _get_unit_at(spawn_pos) != null:
			spawn_pos = _find_reinforcement_spawn()
		if spawn_pos.x < 0:
			# 无可用出生点，跳过本次增援
			continue
		var unit = GameData.create_enemy_unit(enemy_type)
		unit.grid_pos = spawn_pos
		unit.height = MapLoader.get_height_at(map_data, spawn_pos.x, spawn_pos.y)
		_apply_difficulty_to_enemy(unit)
		enemy_units.append(unit)
		# 渲染新单位精灵
		_create_unit_sprite(unit)
		_log("增援到达：%s (%d,%d)" % [unit.unit_name, spawn_pos.x, spawn_pos.y])

## 在地图边缘（敌人侧）寻找可用的增援出生点
func _find_reinforcement_spawn() -> Vector2i:
	# 优先在地图右侧（敌人侧）边缘找空位
	for attempt in 20:
		var x = map_width - 1 - (attempt % 3)
		var y = (attempt / 3) % map_height
		var pos = Vector2i(x, y)
		if GridSystem.is_in_bounds(pos, map_width, map_height) and _get_unit_at(pos) == null:
			if not _is_blocked(pos):
				return pos
	# 回退：扫描全图找空位
	for y in range(map_height):
		for x in range(map_width):
			var pos = Vector2i(x, y)
			if _get_unit_at(pos) == null and not _is_blocked(pos):
				return pos
	return Vector2i(-1, -1)

func _on_battle_won(result: Dictionary) -> void:
	_log("胜利！")
	_finish_battle(true, result)

func _on_battle_lost(result: Dictionary) -> void:
	_log("失败...")
	_finish_battle(false, result)

func _finish_battle(victory: bool, result: Dictionary) -> void:
	await get_tree().create_timer(1.5).timeout

	var stars = 0
	var survived = player_units.filter(func(u): return u.is_alive).size()
	var total = player_units.size()

	if victory:
		stars = 1
		if survived == total:
			stars = 2
		if turn_manager.turn_number <= 10:
			stars = 3

	var level_rewards = level_config.get("rewards", {})
	var diff_params = GameManager.get_difficulty_params()
	var reward_mult = float(diff_params.get("reward_multiplier", 1.0))
	var rewards = {
		"credit": int(round(level_rewards.get("credit", 200) * reward_mult)),
		"exp": int(round(level_rewards.get("exp", 150) * reward_mult)),
		"intel": 0,
	}

	var battle_result = {
		"result": "victory" if victory else "defeat",
		"level_id": level_id,
		"stars": stars,
		"turns": turn_manager.turn_number,
		"units_survived": survived,
		"units_total": total,
		"survivor_count": survived,
		"rewards": rewards if victory else {},
		"rating": stars,
	}
	# 收集遥测数据并附加到 battle_result
	battle_result = _finalize_telemetry(battle_result)

	if victory:
		GameManager.complete_mission(battle_result)
		# 胜利时播放 outro 对话，结束后再跳转到结算界面
		_play_outro_then_finish(battle_result)
	else:
		# 失败时仅记录失败统计，不修改关卡进度，确保不会产生不可逆死档
		GameManager.fail_mission(battle_result)
		GameManager.go_to_mission_result(battle_result)

func _play_outro_then_finish(battle_result: Dictionary) -> void:
	var outro_id = level_config.get("outro_dialogue", "")
	if outro_id == "":
		GameManager.go_to_mission_result(battle_result)
		return
	GameManager.play_level_dialogue(level_id, "outro", Callable(self, "_go_to_result").bind(battle_result))

func _go_to_result(battle_result: Dictionary) -> void:
	# 检查是否是最终 Boss 关卡，触发结局
	if level_id == "ch5_m5":
		_trigger_ending()
	GameManager.go_to_mission_result(battle_result)

## 最终 Boss 通关后触发结局选择
## 这里简化处理：根据玩家在关卡中的剧情旗标决定结局
func _trigger_ending() -> void:
	# ch5_m4 的 ending_choice 旗标由对话系统设置
	# 若未设置任何旗标，默认 ending_a
	var ending = "ending_a"
	if GameManager.get_story_flag("chose_ending_b", false):
		ending = "ending_b"
	elif GameManager.get_story_flag("chose_ending_c", false):
		ending = "ending_c"
	GameManager.unlock_ending(ending)

## ===== 敌人回合 =====

func _run_enemy_turn() -> void:
	# 敌人回合开始时处理 Boss 专属能力（召唤、护盾恢复等）
	_process_boss_abilities()
	for enemy in enemy_units:
		if not enemy.is_alive:
			continue
		if turn_manager.battle_over:
			break
		await _execute_enemy_action(enemy)
		await get_tree().create_timer(0.3).timeout

	if not turn_manager.battle_over:
		turn_manager.end_enemy_turn()

func _execute_enemy_action(enemy: Unit) -> void:
	# 每个敌人执行一次行动（攻击或移动），消耗1AP
	if enemy.current_ap <= 0:
		return

	var action = UtilityAI.decide_action(enemy, player_units, map_data, enemy_units)

	match action.get("type", "wait"):
		"attack":
			var target = action.get("target")
			if target and target.is_alive:
				_do_attack(enemy, target)
		"move":
			var pos = action.get("target_pos", Vector2i(-1, -1))
			if pos.x >= 0:
				_do_enemy_move(enemy, pos)
		"move_to_cover":
			var pos = action.get("target_pos", Vector2i(-1, -1))
			if pos.x >= 0:
				_do_enemy_move(enemy, pos)
		"overwatch":
			enemy.add_status("overwatch", 1)
			enemy.spend_ap(1)
			_log("%s 进入警戒" % enemy.unit_name)
		"wait":
			pass

	# 如果还有AP，再行动一次
	if enemy.current_ap > 0 and enemy.is_alive and not turn_manager.battle_over:
		var action2 = UtilityAI.decide_action(enemy, player_units, map_data, enemy_units)
		match action2.get("type", "wait"):
			"attack":
				var target = action2.get("target")
				if target and target.is_alive:
					_do_attack(enemy, target)
			"overwatch":
				enemy.add_status("overwatch", 1)
				enemy.spend_ap(1)

func _do_enemy_move(enemy: Unit, target_pos: Vector2i) -> void:
	var path = Pathfinding.find_path(
		enemy.grid_pos, target_pos,
		map_width, map_height,
		_get_move_cost.bind(enemy.job),
		_is_blocked
	)
	if path.is_empty():
		return

	var cost = 0
	var last_pos = enemy.grid_pos
	for cell in path:
		var terrain = MapLoader.get_terrain_at(map_data, cell.x, cell.y)
		var step_cost = 1
		match terrain:
			2, 3, 8: step_cost = 2
		if cost + step_cost > enemy.move_points:
			break
		cost += step_cost
		last_pos = cell

	if last_pos != enemy.grid_pos:
		enemy.move_to(last_pos)
		_update_unit_sprite_pos(enemy)
		_log("%s 移动到 (%d,%d)" % [enemy.unit_name, last_pos.x, last_pos.y])

## ===== 玩家输入 =====

func _unhandled_input(event: InputEvent) -> void:
	if turn_manager.input_locked or turn_manager.battle_over:
		return
	if turn_manager.current_phase != TurnManager.TurnPhase.PLAYER_ACTION:
		return

	if event.is_action_pressed("pause"):
		_show_pause_menu()
		return

	if event.is_action_pressed("end_turn"):
		_end_player_turn()
		return

	# 鼠标移动时实时预览移动路径
	if event is InputEventMouseMotion and selected_action == "move" and selected_unit:
		_update_path_preview(get_global_mouse_position())

	if event is InputEventMouseButton and event.pressed:
		var world_pos = get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(world_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_action()

func _handle_left_click(world_pos: Vector2) -> void:
	var grid_pos = GridSystem.world_to_grid(world_pos)
	if not GridSystem.is_in_bounds(grid_pos, map_width, map_height):
		return

	match selected_action:
		"move":
			# 先检查是否点击了终端（steal_data/infiltrate 任务交互）
			if mission_type in ["steal_data", "infiltrate"] and grid_pos in terminals:
				if selected_unit and selected_unit.team == "player":
					if _try_interact_terminal(selected_unit, grid_pos):
						_show_move_range(selected_unit)
						hud.update_unit_info(selected_unit)
						return
			_try_move(grid_pos)
		"attack":
			_try_attack(grid_pos)
		"":
			# 选择单位
			var unit = _get_unit_at(grid_pos)
			if unit and unit.is_alive:
				_select_unit(unit)
			else:
				_deselect_unit()

func _select_unit(unit: Unit) -> void:
	_deselect_unit()
	selected_unit = unit
	_update_unit_sprite_selection(unit, true)
	hud.update_unit_info(unit)
	_show_move_range(unit)

func _deselect_unit() -> void:
	if selected_unit:
		_update_unit_sprite_selection(selected_unit, false)
	selected_unit = null
	selected_action = ""
	reachable_cells.clear()
	attack_targets.clear()
	path_preview.clear()
	_clear_layer(move_highlight)
	_clear_layer(path_preview_layer)
	_clear_layer(attack_highlight)
	hud.update_unit_info(null)
	hud.set_action_buttons_visible(false)

func _cancel_action() -> void:
	if selected_action != "":
		selected_action = ""
		_clear_layer(attack_highlight)
		_clear_layer(path_preview_layer)
		path_preview.clear()
		if selected_unit:
			_show_move_range(selected_unit)
	else:
		_deselect_unit()

## ===== 行动执行 =====

func _show_move_range(unit: Unit) -> void:
	_clear_layer(move_highlight)
	reachable_cells = Pathfinding.get_reachable_cells(
		unit.grid_pos, unit.move_points,
		map_width, map_height,
		_get_move_cost.bind(unit.job),
		_is_blocked
	)
	for cell in reachable_cells:
		if cell == unit.grid_pos:
			continue
		_highlight_cell(move_highlight, cell, COLOR_MOVE)

	# 标记撤离点
	if mission_type in ["extract", "steal_data", "escort", "infiltrate"] and evac_point.x >= 0:
		if reachable_cells.has(evac_point) or unit.grid_pos == evac_point:
			_highlight_cell(move_highlight, evac_point, COLOR_EVAC)

	# 标记终端（steal_data/infiltrate 任务）
	if mission_type in ["steal_data", "infiltrate"]:
		for term_pos in terminals:
			# 终端相邻格可达时高亮终端
			if _is_adjacent_reachable(unit, term_pos):
				_highlight_cell(move_highlight, term_pos, COLOR_TARGET)

## 鼠标悬停时实时预览从选中单位到鼠标格的移动路径
## 仅在 move 模式下、目标格可达时绘制路径线条和途径格子高亮
func _update_path_preview(world_pos: Vector2) -> void:
	_clear_layer(path_preview_layer)
	if not selected_unit or selected_action != "move":
		return
	var grid_pos = GridSystem.world_to_grid(world_pos)
	if not GridSystem.is_in_bounds(grid_pos, map_width, map_height):
		return
	# 目标格必须可达（不含起点）
	if not reachable_cells.has(grid_pos):
		return
	if grid_pos == selected_unit.grid_pos:
		return
	var path = Pathfinding.find_path(
		selected_unit.grid_pos, grid_pos,
		map_width, map_height,
		_get_move_cost.bind(selected_unit.job),
		_is_blocked
	)
	if path.size() < 2:
		return
	path_preview = path
	# 绘制路径途径格子（不含起点，含终点）
	for i in range(1, path.size()):
		var cell = path[i]
		# 终点用更亮的高亮
		var color = COLOR_PATH if i < path.size() - 1 else Color(0.1, 1.0, 0.2, 0.45)
		_highlight_cell(path_preview_layer, cell, color)
	# 绘制连接线
	_draw_path_line(path)

## 在路径预览层上绘制途径格之间的连接线
func _draw_path_line(path: Array) -> void:
	if path.size() < 2:
		return
	var line = Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.2, 1.0, 0.3, 0.8)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	for cell in path:
		var world = GridSystem.grid_to_world(cell) + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
		line.add_point(world)
	path_preview_layer.add_child(line)

func _show_attack_range(unit: Unit) -> void:
	_clear_layer(attack_highlight)
	attack_targets.clear()
	# 敌方单位
	for enemy in enemy_units:
		if not enemy.is_alive:
			continue
		var dist = GridSystem.manhattan_distance(unit.grid_pos, enemy.grid_pos)
		if dist >= unit.weapon_range[0] and dist <= unit.weapon_range[1]:
			var has_los = VisionSystem.has_line_of_sight(
				unit.grid_pos, enemy.grid_pos,
				map_width, map_height, _is_vision_blocking
			)
			if has_los:
				attack_targets.append(enemy)
				_highlight_cell(attack_highlight, enemy.grid_pos, COLOR_ATTACK)
	# 可破坏目标（destroy 任务）
	for tpos in destructible_targets:
		var state = destructible_target_states.get(tpos, {})
		if state.get("destroyed", false):
			continue
		var dist = GridSystem.manhattan_distance(unit.grid_pos, tpos)
		if dist >= unit.weapon_range[0] and dist <= unit.weapon_range[1]:
			var has_los = VisionSystem.has_line_of_sight(
				unit.grid_pos, tpos,
				map_width, map_height, _is_vision_blocking
			)
			if has_los:
				attack_targets.append(tpos)  # 混合类型：Unit 和 Vector2i
				_highlight_cell(attack_highlight, tpos, COLOR_TARGET)

## 检查单位的可达格中是否有与目标格相邻的
func _is_adjacent_reachable(unit: Unit, target_pos: Vector2i) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			# 只考虑正交相邻（上下左右）
			if dx != 0 and dy != 0:
				continue
			var adj = Vector2i(target_pos.x + dx, target_pos.y + dy)
			if adj == unit.grid_pos or reachable_cells.has(adj):
				return true
	return false

func _try_move(grid_pos: Vector2i) -> void:
	if not selected_unit or not reachable_cells.has(grid_pos):
		return
	if not selected_unit.can_move():
		_log("无法移动")
		return

	var cost = reachable_cells[grid_pos]
	if cost > selected_unit.move_points:
		_log("移动点不足")
		return

	var old_pos = selected_unit.grid_pos
	selected_unit.move_points -= cost
	selected_unit.move_to(grid_pos)
	_update_unit_sprite_pos(selected_unit)

	# 检查警戒触发
	var triggers = action_system.check_overwatch_trigger(selected_unit, old_pos, grid_pos)
	for t in triggers:
		_log("%s 警戒射击 %s!" % [t.watcher.unit_name, t.target.unit_name])
		_update_unit_sprite_pos(t.target)

	_log("%s 移动到 (%d,%d)" % [selected_unit.unit_name, grid_pos.x, grid_pos.y])
	_clear_layer(path_preview_layer)
	path_preview.clear()
	_show_move_range(selected_unit)
	hud.update_unit_info(selected_unit)

	_check_victory_instant()

func _try_attack(grid_pos: Vector2i) -> void:
	if not selected_unit:
		return
	# 先检查是否点击了可破坏目标
	if grid_pos in destructible_targets:
		var state = destructible_target_states.get(grid_pos, {})
		if not state.get("destroyed", false) and grid_pos in attack_targets:
			_attack_destructible(selected_unit, grid_pos)
			# 刷新攻击范围显示
			if selected_unit and selected_unit.current_ap > 0:
				_show_attack_range(selected_unit)
			else:
				selected_action = ""
				_clear_layer(attack_highlight)
			hud.update_unit_info(selected_unit)
			return
	# 检查敌方单位
	var target = _get_unit_at(grid_pos)
	if not target or target.team == "player":
		return
	if not target in attack_targets:
		_log("目标不在攻击范围")
		return

	_do_attack(selected_unit, target)
	# 刷新攻击范围显示
	if selected_unit and selected_unit.current_ap > 0:
		_show_attack_range(selected_unit)
	else:
		selected_action = ""
		_clear_layer(attack_highlight)
	hud.update_unit_info(selected_unit)

## 攻击可破坏目标实体（消耗 AP，造成武器伤害）
func _attack_destructible(attacker: Unit, target_pos: Vector2i) -> void:
	if not attacker.can_act():
		_log("无法行动")
		return
	if not attacker.spend_ap(1):
		_log("AP 不足")
		return
	var state = destructible_target_states.get(target_pos, {})
	if state.is_empty():
		return
	# 计算伤害（可破坏目标无护甲、无闪避，固定命中）
	var avg_dmg = int((attacker.weapon_damage[0] + attacker.weapon_damage[1]) / 2)
	state.hp = max(0, int(state.hp) - avg_dmg)
	# 记录遥测：可破坏目标算作命中
	_telemetry.shots_fired += 1
	_telemetry.shots_hit += 1
	_telemetry.damage_dealt += avg_dmg
	_log("%s 攻击目标 (%d,%d) - %d伤害" % [attacker.unit_name, target_pos.x, target_pos.y, avg_dmg])
	if state.hp <= 0 and not state.destroyed:
		state.destroyed = true
		targets_destroyed += 1
		_log("目标已摧毁 %d/%d" % [targets_destroyed, targets_required])
		# 从攻击范围移除已摧毁的目标
		attack_targets.erase(target_pos)
	destructible_target_states[target_pos] = state
	hud.update_objective(_get_objective_text())
	_check_victory_instant()

## 尝试激活终端（玩家单位相邻时点击终端触发）
func _try_interact_terminal(unit: Unit, term_pos: Vector2i) -> bool:
	if not term_pos in terminals:
		return false
	if not _is_adjacent_reachable(unit, term_pos) and unit.grid_pos != term_pos:
		_log("终端不在可达范围")
		return false
	if not unit.can_act():
		_log("无法行动")
		return false
	if not unit.spend_ap(1):
		_log("AP 不足")
		return false
	terminals_activated += 1
	_log("%s 激活终端 (%d/%d)" % [unit.unit_name, terminals_activated, terminals_required])
	hud.update_objective(_get_objective_text())
	_check_victory_instant()
	return true

func _do_attack(attacker: Unit, target: Unit) -> void:
	var result = action_system.execute_attack(attacker, target)
	if result.get("success", false):
		var r = result.get("result", {})
		var hit = r.get("hit", false)
		var damage = int(r.get("damage", 0))
		var critical = r.get("critical", false)
		if hit:
			if r.get("dodged", false):
				_log("%s 攻击 %s - 闪避!" % [attacker.unit_name, target.unit_name])
			elif critical:
				_log("%s 暴击 %s - %d伤害!" % [attacker.unit_name, target.unit_name, damage])
			else:
				_log("%s 命中 %s - %d伤害" % [attacker.unit_name, target.unit_name, damage])
		else:
			_log("%s 攻击 %s - 未命中" % [attacker.unit_name, target.unit_name])
		# 记录遥测：闪避算作命中（攻击命中判定通过，但被闪避）
		_record_attack_telemetry(attacker, target, hit, damage, critical)
		_update_unit_sprite_pos(target)
	else:
		_log("攻击失败: %s" % result.get("reason", "unknown"))

func _end_player_turn() -> void:
	_deselect_unit()
	turn_manager.end_player_turn()

## ===== HUD 按钮回调 =====

func on_move_button() -> void:
	if selected_unit and selected_unit.team == "player":
		selected_action = "move"
		_clear_layer(attack_highlight)
		_show_move_range(selected_unit)

func on_attack_button() -> void:
	if selected_unit and selected_unit.team == "player" and selected_unit.current_ap > 0:
		selected_action = "attack"
		_show_attack_range(selected_unit)

func on_skill_button() -> void:
	if not selected_unit or selected_unit.team != "player" or selected_unit.current_ap <= 0:
		return
	# 配置驱动：使用单位已学技能列表
	var skills = selected_unit.learned_skills
	if skills.is_empty():
		# 回退：该职业第一个可用技能
		var job_skills = GameData.get_job_skills(selected_unit.job)
		if job_skills.is_empty():
			_log("%s 没有可用技能" % selected_unit.unit_name)
			return
		skills = [job_skills[0].id]
	# 循环选择技能（每次按按钮切换到下一个技能）
	_skill_cycle_index = (_skill_cycle_index + 1) % skills.size()
	var skill_id = skills[_skill_cycle_index]
	var skill_data = GameData.get_skill(skill_id)
	var skill_name = skill_data.get("name", skill_id)
	# 需要目标的技能：先提示选择目标（简化为直接施放自身/无目标）
	var target_data := {}
	if skill_data.get("target") == "enemy" or skill_data.get("target") == "position":
		# 需要目标的技能暂用自身位置作为回退（真实实现应进入目标选择模式）
		target_data = {"position": selected_unit.grid_pos}
	var skill_result = action_system.execute_skill(selected_unit, skill_id, target_data)
	if skill_result.get("success", false):
		_log("%s 使用技能：%s" % [selected_unit.unit_name, skill_name])
		_record_skill_telemetry()
		hud.update_unit_info(selected_unit)
	else:
		_log("%s 技能 %s 失败：%s" % [selected_unit.unit_name, skill_name, skill_result.get("reason", "")])

func on_item_button() -> void:
	if not selected_unit or selected_unit.team != "player":
		return
	# 配置驱动：使用单位可用物品列表
	var items = selected_unit.available_items
	if items.is_empty():
		items = ["med_kit"]  # 回退
	# 循环选择物品
	_item_cycle_index = (_item_cycle_index + 1) % items.size()
	var item_id = items[_item_cycle_index]
	var item_data = GameData.get_item(item_id)
	var item_name = item_data.get("name", item_id)
	var item_result = action_system.use_item(selected_unit, item_id, selected_unit, {})
	if item_result.get("success", false):
		_log("%s 使用物品：%s" % [selected_unit.unit_name, item_name])
		_record_item_telemetry()
		hud.update_unit_info(selected_unit)
	else:
		_log("%s 物品 %s 失败：%s" % [selected_unit.unit_name, item_name, item_result.get("reason", "")])

func on_overwatch_button() -> void:
	if selected_unit and selected_unit.team == "player" and selected_unit.current_ap > 0:
		if action_system.enter_overwatch(selected_unit):
			_log("%s 进入警戒" % selected_unit.unit_name)
			_record_overwatch_telemetry()
			hud.update_unit_info(selected_unit)

func on_end_turn_button() -> void:
	_end_player_turn()

## ===== 单位事件回调 =====

func _on_unit_ap_changed(unit: Unit, _ap: int) -> void:
	if selected_unit == unit:
		hud.update_unit_info(unit)

func _on_unit_died(unit: Unit) -> void:
	_log("%s 阵亡" % unit.unit_name)
	_update_unit_sprite_pos(unit)
	_record_death_telemetry(unit)
	# Boss 死亡时更新目标显示
	if unit == boss_unit:
		_log("Boss 已被击杀！")
		hud.update_objective(_get_objective_text())

func _on_unit_damaged(unit: Unit, _amount: int) -> void:
	_update_unit_sprite_pos(unit)
	# Boss 受伤时检查阶段切换
	if unit == boss_unit and boss_unit and boss_unit.is_alive:
		_check_boss_phase_transition(unit)

func _check_victory_instant() -> void:
	if _check_victory():
		turn_manager._end_battle(true)

## ===== 辅助函数 =====

func _get_unit_at(pos: Vector2i) -> Unit:
	for unit in player_units + enemy_units:
		if unit and unit.is_alive and unit.grid_pos == pos:
			return unit
	return null

func _update_unit_sprite_pos(unit: Unit) -> void:
	for sprite in unit_layer.get_children():
		if sprite is UnitSprite and sprite.unit == unit:
			sprite.position = GridSystem.grid_to_world(unit.grid_pos)
			sprite.update_unit(unit)
			return

func _update_unit_sprite_selection(unit: Unit, selected: bool) -> void:
	for sprite in unit_layer.get_children():
		if sprite is UnitSprite and sprite.unit == unit:
			sprite.set_selected(selected)
			return

func _get_move_cost(pos: Vector2i, job: String) -> int:
	return GameData.get_move_cost(job, MapLoader.get_terrain_at(map_data, pos.x, pos.y))

func _is_blocked(pos: Vector2i) -> bool:
	if not MapLoader.is_passable(map_data, pos.x, pos.y):
		return true
	# 被其他单位占据的格子不可通行
	for unit in player_units + enemy_units:
		if unit and unit.is_alive and unit.grid_pos == pos:
			return true
	return false

func _is_vision_blocking(pos: Vector2i) -> bool:
	var blocker = MapLoader.get_blocker_at(map_data, pos.x, pos.y)
	return blocker == 6

func _log(msg: String) -> void:
	hud.add_log(msg)

func _show_pause_menu() -> void:
	var pause = preload("res://scenes/pause_menu.tscn").instantiate()
	add_child(pause)
