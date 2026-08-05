## 战斗场景控制器
## 单一战斗状态源：管理地图、单位、回合、行动和渲染
extends Node2D
class_name BattleController

const CELL_SIZE = 64
const MAP_VISUAL_MARGIN = 40
const TutorialHintScene = preload("res://scenes/tutorial_hint.tscn")
const V2ActionServiceScript = preload("res://scripts/v2/combat/v2_action_service.gd")
const V2AffordancePresenterScript = preload("res://scripts/v2/presentation/v2_affordance_presenter.gd")

## CH1-030: 上下文教程 flag 期望的动作类型映射（玩家完成对应动作后推进提示）
## CH1-080: M1 只教学选择/移动/攻击/观察/接管/结束回合六项
const CONTEXT_HINT_ACTION := {
	"teach_selection": "select",
	"teach_movement": "move",
	"teach_attack": "attack",
	"teach_observe": "observe",
	"teach_interaction": "interact",
	"teach_network_scan": "network",
	"teach_network_takeover": "network",
	"teach_end_turn": "end_turn",
}

## 待展示的教程 flag 队列（来自 level_config.tutorial_flags，跳过已读）
var _pending_tutorial_flags: Array[String] = []
## 当前活跃的教程提示实例
var _active_tutorial_hint: Control = null
## CH1-030: 上下文教学提示队列（战斗中伴随式显示，玩家完成动作后推进）
var _context_hint_queue: Array[String] = []
## CH1-030: 当前活跃的上下文提示实例
var _active_context_hint: Control = null
## CH1-030: 当前上下文提示对应的 flag
var _active_context_flag: String = ""

## 渲染层
@onready var map_layer: Node2D = $MapLayer
@onready var evac_zone_layer: Node2D = $EvacZoneLayer
@onready var move_highlight: Node2D = $MoveHighlightLayer
@onready var path_preview_layer: Node2D = $PathPreviewLayer
@onready var attack_highlight: Node2D = $AttackHighlightLayer
@onready var v2_affordance_layer: Node2D = $V2AffordanceLayer
@onready var unit_layer: Node2D = $UnitLayer
@onready var effect_layer: Node2D = $EffectLayer
@onready var hud: HUD = $HUD
@onready var camera: BattleCameraController = $Camera2D
## CH1-040: 迷雾渲染层。程序化添加，位于 EvacZoneLayer 与 MoveHighlightLayer 之间，
## 使其遮挡地形与撤离区，但不遮挡玩家高亮、单位与特效。
var visibility_renderer: VisibilityRenderer = null
## CH1-040: 活跃摄像头区域格子集合（供渲染器同步显示摄像头维持的观察区）
var _camera_zone_cells: Array[Vector2i] = []
## CH1-040: 已渲染的最后已知位置幽灵标记，entity_id -> UnitSprite
var _last_known_ghosts: Dictionary = {}
## CH1-050: 敌方意图渲染层。程序化添加，位于单位层之上，绘制观察到的敌人意图。
var enemy_intent_renderer: EnemyIntentRenderer = null
## CH1-050: 是否已在敌回合前生成下回合计划（避免重复规划）。
var _enemy_intents_planned: bool = false

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
var selected_action: String = ""  # "", "move", "attack", "skill", "item", "targeting"
var reachable_cells: Dictionary = {}
var attack_targets: Array = []
var v2_attack_range_cells: Array[Vector2i] = []
## 直接点击敌人时的二次确认目标，避免误触立即结算攻击。
var attack_preview_target: Unit = null
var attack_preview_data: Dictionary = {}
var attack_confirmation_required := false
var last_player_attack_result: Dictionary = {}
var path_preview: Array[Vector2i] = []
# 当前正在选择目标的技能/物品 ID（由 HUD 行动选择面板设置）
var _pending_action_id: String = ""
# 当前正在选择目标的行动类型："skill" / "item"
var _pending_action_kind: String = ""

## 子系统
var turn_manager: TurnManager
var action_system: ActionSystem
var enemy_director: EnemyDirector
var targeting_controller: TargetingController
var mission_objective_state: MissionObjectiveState
## CODE-P2-01: Visibility memory and enemy intent
var visibility_state: VisibilityState
var enemy_intent_state: EnemyIntentState
var enemy_planner: EnemyPlanner
## V2 P1 服务槽位。正式输入仍使用旧 ActionSystem，P2 逐合同切换。
var v2_action_service: V2ActionService = null
var v2_mission_flow: Dictionary = {}
var v2_interaction_service: RefCounted = null
var v2_affordance_presenter: V2AffordancePresenter = null
## CODE-P2-02: Tactical network and alert state
var tactical_network_state: TacticalNetworkState
## 网络节点精灵（覆盖层显示时可见）
var _network_node_sprites: Dictionary = {}
## CH1-060: 网络连接线节点（覆盖层显示时可见）
var _network_connection_lines: Array = []
## CH1-060: 网络状态形状指示器（覆盖层显示时可见）
var _network_shape_nodes: Dictionary = {}
var alert_state: AlertState
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## CH1-080: 当前遭遇区 ID（用于失败重试时定位最近检查点）
var current_encounter_id: String = ""

## 胜利条件
var mission_type: String = "extract"
var evac_point: Vector2i = Vector2i(-1, -1)
var evac_cells: Array[Vector2i] = []
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
var resource_positions: Array[Vector2i] = []
## Boss 单位引用（assassinate 任务）
var boss_unit: Unit = null
## Boss 阶段状态（由 bosses.json 的 phases 驱动）
var boss_data: Dictionary = {}
var boss_phases: Array = []
var boss_current_phase: int = 0
var boss_max_hp_for_phase: int = 0
## Boss 专属能力运行时状态：ability_id -> { "counter": int, "last_turn": int }
var boss_ability_state: Dictionary = {}
## CODE-CH1-020: Boss 召唤计数器，用于派生稳定 entity_id（不依赖 enemy_units 数组顺序）
var _boss_summon_counter: int = 0
## Boss 预警旗标：每个阶段是否已展示过预警
var boss_phase_warned: Array[bool] = []
## 护送 VIP 单位引用（escort 任务）
var escort_vip: Unit = null

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
const COLOR_ATTACK_RANGE = Color(0.96, 0.26, 0.21, 0.13)
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
	_setup_visibility_renderer()
	_setup_enemy_intent_renderer()
	_spawn_units()
	_setup_v2_services()
	_setup_v2_affordance_presenter()
	_setup_objective_state()
	_setup_victory_conditions()
	_init_telemetry()
	_render_map()
	_configure_viewport_layout()
	get_viewport().size_changed.connect(_configure_viewport_layout)
	_render_units()
	# 先播放 intro 对话，结束后再开始战斗
	_play_intro_then_start()

## CH1-040: 创建并挂载 VisibilityRenderer，置于 EvacZoneLayer 与 MoveHighlightLayer 之间。
## 雾层遮挡地形与撤离区，但不遮挡玩家高亮、单位与特效。
func _setup_visibility_renderer() -> void:
	visibility_renderer = VisibilityRenderer.new()
	visibility_renderer.name = "VisibilityRenderer"
	# Fog must cover unexplored environment props, while UnitSprite/FX keep their
	# higher z-indices so readable gameplay actors remain visible.
	visibility_renderer.z_index = 2
	add_child(visibility_renderer)
	# 插入到 MoveHighlightLayer 当前位置，使雾层位于 EvacZoneLayer 与 MoveHighlightLayer 之间。
	if move_highlight:
		move_child(visibility_renderer, move_highlight.get_index())
	visibility_renderer.setup(visibility_state, map_width, map_height, float(CELL_SIZE))


## CH1-050: 创建并挂载 EnemyIntentRenderer，位于单位层之上，绘制观察到的敌人意图
## （攻击箭头、移动目标、警戒、致命/过期标记）。仅显示公开意图，不读取原始 AI 状态。
func _setup_enemy_intent_renderer() -> void:
	enemy_intent_renderer = EnemyIntentRenderer.new()
	enemy_intent_renderer.name = "EnemyIntentRenderer"
	add_child(enemy_intent_renderer)
	# 放到 effect_layer 之上，确保箭头不被特效层遮挡；但 z_index 仍由 EnemyIntentRenderer
	# 自身控制（95），位于单位（100+）之下，避免遮挡单位本体。
	if effect_layer:
		move_child(enemy_intent_renderer, effect_layer.get_index() + 1)
	enemy_intent_renderer.setup(enemy_intent_state, visibility_state, float(CELL_SIZE), map_width, map_height)

## 初始化任务目标状态机，并把 battle_controller 的目标变量同步为 mos 的权威状态。
## mos 持有任务目标的真实状态；battle_controller 的同名变量作为只读镜像供渲染和旧代码使用。
func _setup_objective_state() -> void:
	var designations := {
		"boss_unit": boss_unit,
		"escort_vip": escort_vip,
	}
	mission_objective_state.setup(level_config, map_data, player_units, enemy_units, designations)
	mission_objective_state.mission_event.connect(_on_mission_event)
	# Configure reinforcement triggers early so mission events can spawn waves
	# before _start_battle() completes (e.g. during E2E integration tests).
	enemy_director.setup(map_data.get("scripts", []))
	# CH1-050: Wire enemy intent state and planner now that visibility_state and
	# map_data are both ready. Planning happens at end of player turn; the
	# renderer reads public intents each refresh.
	enemy_intent_state.setup(visibility_state)
	enemy_planner.setup(map_data)
	_sync_objective_state_from_mos()

## 从 mos 同步目标状态到 battle_controller 的镜像变量。
## Dictionary/Array 为引用类型，同步后双方共享同一份数据；基本类型需在写操作后重新同步。
func _sync_objective_state_from_mos() -> void:
	mission_type = mission_objective_state.mission_type
	evac_point = mission_objective_state.evac_point
	evac_cells = mission_objective_state.evac_cells
	destructible_targets = mission_objective_state.destructible_targets
	destructible_target_states = mission_objective_state.destructible_target_states
	targets_destroyed = mission_objective_state.targets_destroyed
	targets_required = mission_objective_state.targets_required
	terminals = mission_objective_state.terminals
	terminals_activated = mission_objective_state.terminals_activated
	terminals_required = mission_objective_state.terminals_required
	boss_unit = mission_objective_state.boss_unit
	escort_vip = mission_objective_state.escort_vip

## mos 目标文本更新回调：刷新 HUD
func _on_objective_updated(_text: String) -> void:
	hud.update_objective(mission_objective_state.get_status_text())

## 退出场景树时释放未挂载的单位节点，避免资源泄漏
func _exit_tree() -> void:
	# 取消任何进行中的目标选择，避免信号回调悬空
	if targeting_controller and targeting_controller.is_active:
		targeting_controller.cancel()
	_cleanup_units()

## 释放所有单位节点（player_units 和 enemy_units 中的 Unit 实例）
## 这些 Unit 是 Node2D 但未添加到场景树，需要手动释放
func _cleanup_units() -> void:
	for unit in player_units:
		if unit and is_instance_valid(unit):
			# Units are data nodes, not scene-tree children; deferred deletion never
			# reaches the queue for detached nodes during a scene transition.
			unit.free()
	for unit in enemy_units:
		if unit and is_instance_valid(unit):
			unit.free()
	player_units.clear()
	enemy_units.clear()
	# CH1-040: 清理最后已知位置幽灵标记及其临时 Unit 占位
	for ghost in _last_known_ghosts.values():
		if ghost and is_instance_valid(ghost):
			var placeholder = ghost.unit
			ghost.queue_free()
			if placeholder and is_instance_valid(placeholder):
				placeholder.free()
	_last_known_ghosts.clear()
	_camera_zone_cells.clear()
	_dismiss_context_hint()
	selected_unit = null
	boss_unit = null
	boss_data.clear()
	boss_phases.clear()
	boss_current_phase = 0
	boss_max_hp_for_phase = 0
	boss_ability_state.clear()
	_boss_summon_counter = 0
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
	hud.add_child(_active_tutorial_hint)
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

## CH1-030: 战斗开始后启动上下文教学提示序列（伴随式、非阻断）
func _begin_context_tutorials() -> void:
	_context_hint_queue.clear()
	for f in level_config.get("context_tutorial_flags", []):
		_context_hint_queue.append(String(f))
	_show_next_context_hint()

## CH1-030: 显示下一个未读上下文提示；无剩余则清理
func _show_next_context_hint() -> void:
	while _context_hint_queue.size() > 0:
		var flag = _context_hint_queue.pop_front()
		if not TutorialHint.is_known(flag):
			_show_context_hint(flag)
			return
	# 无剩余上下文提示
	_dismiss_context_hint()

## CH1-030: 实例化并显示单个上下文提示
func _show_context_hint(flag: String) -> void:
	_dismiss_context_hint()
	_active_context_hint = TutorialHintScene.instantiate()
	hud.add_child(_active_context_hint)
	_active_context_flag = flag
	_active_context_hint.show_context_hint(flag)

## CH1-030: 清理当前上下文提示实例
func _dismiss_context_hint() -> void:
	if _active_context_hint != null and is_instance_valid(_active_context_hint):
		_active_context_hint.queue_free()
	_active_context_hint = null
	_active_context_flag = ""

## CH1-030: 玩家完成动作后推进上下文提示
## action_type: "move" / "attack" / "interact" / "network" / "end_turn"
func _advance_context_hint(action_type: String) -> void:
	if _active_context_flag == "":
		return
	var expected: String = String(CONTEXT_HINT_ACTION.get(_active_context_flag, ""))
	if expected == "" or expected == action_type:
		TutorialHint.mark_known(_active_context_flag)
		_show_next_context_hint()

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
	action_system.ground_effects_changed.connect(_render_ground_effects)

	enemy_director = EnemyDirector.new()
	add_child(enemy_director)
	enemy_director.reinforcement_spawned.connect(_on_reinforcement_spawned)
	enemy_director.player_reinforcement_spawned.connect(_on_player_reinforcement_spawned)

	targeting_controller = TargetingController.new()
	add_child(targeting_controller)
	targeting_controller.targeting_started.connect(_on_targeting_started)
	targeting_controller.target_confirmed.connect(_on_target_confirmed)
	targeting_controller.targeting_cancelled.connect(_on_targeting_cancelled)

	mission_objective_state = MissionObjectiveState.new()
	add_child(mission_objective_state)
	mission_objective_state.objective_updated.connect(_on_objective_updated)

	visibility_state = VisibilityState.new()
	add_child(visibility_state)
	enemy_intent_state = EnemyIntentState.new()
	add_child(enemy_intent_state)
	enemy_planner = EnemyPlanner.new()
	add_child(enemy_planner)

	# CODE-P2-02: Tactical network and alert state
	tactical_network_state = TacticalNetworkState.new()
	add_child(tactical_network_state)
	alert_state = AlertState.new()
	add_child(alert_state)
	alert_state.setup()
	alert_state.level_changed.connect(_on_alert_level_changed)
	tactical_network_state.alert_requested.connect(_on_network_alert_requested)
	tactical_network_state.network_operation_performed.connect(_on_network_operation)
	action_system.set_tactical_network_state(tactical_network_state)

	# V2 P1 只创建依赖槽位，不切换 V1 正式输入路径。
	v2_action_service = V2ActionServiceScript.new()
	v2_mission_flow = {"game_line": "v2_infiltration", "state_revision": 0}
	v2_interaction_service = RefCounted.new()

func _setup_v2_services() -> void:
	if v2_action_service == null:
		return
	v2_action_service.setup(map_data, player_units, enemy_units)
	v2_mission_flow["mission_id"] = level_id
	v2_mission_flow["state_revision"] = 1

func _setup_v2_affordance_presenter() -> void:
	if v2_affordance_layer == null:
		return
	v2_affordance_presenter = V2AffordancePresenterScript.new()
	v2_affordance_presenter.name = "V2AffordancePresenter"
	v2_affordance_presenter.cell_size = float(CELL_SIZE)
	v2_affordance_layer.add_child(v2_affordance_presenter)

func _is_v2_battle() -> bool:
	return String(GameManager.current_save.get("game_line", "")) == "v2_infiltration"

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
		elif t == "resource":
			var pos = Vector2i(int(obj.x), int(obj.y))
			if not pos in resource_positions:
				resource_positions.append(pos)
	# destroy 任务所需数量取自 objects 中实际目标数，最少 1
	if mission_type == "destroy":
		targets_required = max(destructible_targets.size(), 1)
	# steal_data / infiltrate 需要激活所有终端
	if mission_type in ["steal_data", "infiltrate"]:
		terminals_required = terminals.size()

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
			# CODE-CH1-020: 优先使用地图提供的稳定 ID；缺失时回退到 team_index
			var stable_id: String = String(obj.get("id", ""))
			unit.entity_id = stable_id if stable_id != "" else "%s_%d" % [unit.team, player_units.size()]
			player_units.append(unit)

		elif obj.type == "spawn_enemy":
			var enemy_type = obj.get("job", "sentry_basic")
			var unit = GameData.create_enemy_unit(enemy_type)
			unit.grid_pos = Vector2i(obj.x, obj.y)
			unit.height = MapLoader.get_height_at(map_data, obj.x, obj.y)
			# CODE-CH1-020: 优先使用地图提供的稳定 ID
			var stable_id: String = String(obj.get("id", ""))
			unit.entity_id = stable_id if stable_id != "" else "%s_%d" % [unit.team, enemy_units.size()]
			_apply_difficulty_to_enemy(unit)
			enemy_units.append(unit)

	# 阵容可能多于本关编制；释放未加入战场的临时 Unit，避免场景切换泄漏。
	for roster_unit in roster_units:
		if roster_unit not in player_units and roster_unit and is_instance_valid(roster_unit):
			roster_unit.free()

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
	var difficulty_params := GameManager.get_difficulty_params()
	var hp_multiplier := float(difficulty_params.get("enemy_hp_multiplier", 1.0))
	var hp = int(round(int(bdata.get("hp", unit.max_hp)) * hp_multiplier))
	unit.max_hp = hp
	unit.current_hp = hp
	unit.armor = int(bdata.get("armor", unit.armor))
	unit.max_shield = int(round(int(bdata.get("shield", 0)) * hp_multiplier))
	unit.current_shield = unit.max_shield
	var boss_name = bdata.get("name", "Boss")
	unit.unit_name = boss_name
	unit.boss_art_key = {
		"数据哨兵": &"boss_data_sentinel",
		"重装审判者": &"boss_heavy_judge",
		"影子佣兵": &"boss_shadow_mercenary",
		"矩阵将军": &"boss_matrix_general",
		"架构师": &"boss_architect",
	}.get(boss_name, &"")
	# 初始化 Boss 阶段状态
	boss_data = bdata.duplicate(true)
	boss_phases = bdata.get("phases", [])
	boss_current_phase = 0
	boss_max_hp_for_phase = hp
	boss_ability_state.clear()
	_boss_summon_counter = 0
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
	var damage = phase.get("damage", [])
	if damage is Array and damage.size() >= 2:
		unit.weapon_damage = [int(damage[0]), int(damage[1])]
		var damage_multiplier := float(GameManager.get_difficulty_params().get("enemy_damage_multiplier", 1.0))
		if damage_multiplier != 1.0:
			unit.weapon_damage[0] = int(round(unit.weapon_damage[0] * damage_multiplier))
			unit.weapon_damage[1] = int(round(unit.weapon_damage[1] * damage_multiplier))
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
		"attack_plus_25":
			if unit.weapon_damage.size() >= 2:
				unit.weapon_damage[0] = int(round(unit.weapon_damage[0] * 1.25))
				unit.weapon_damage[1] = int(round(unit.weapon_damage[1] * 1.25))
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
		for phase_idx in range(boss_current_phase + 1, target_phase + 1):
			_apply_boss_phase(unit, phase_idx)
			_show_boss_phase_warning(phase_idx)
			camera.play_event_feedback(&"boss_phase", _get_cell_center(unit.grid_pos))

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
		"shield_regen_15":
			return "每回合恢复15护盾"
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
		"attack_plus_25":
			return "攻击力+25%"
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
		"shield_regen_15":
			_boss_regen_shield(15)
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
## CODE-CH1-020: 使用 boss_summon 计数器派生稳定 ID，保证多次召唤身份可预测。
func _boss_summon_unit(enemy_type: String, display_name: String) -> void:
	if enemy_director:
		if enemy_director.reinforcements_spawned >= enemy_director.max_reinforcements:
			_log("Boss 召唤失败：全场增援预算已耗尽")
			return
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
	# CODE-CH1-020: 用 boss_summon_<count> 派生稳定 ID，避免依赖 enemy_units.size() 顺序
	_boss_summon_counter += 1
	unit.entity_id = "boss_summon_%d" % _boss_summon_counter
	_apply_difficulty_to_enemy(unit)
	enemy_units.append(unit)
	if enemy_director:
		enemy_director.reinforcements_spawned += 1
	_create_unit_sprite(unit)
	_log("Boss 召唤了 %s (%d,%d)" % [display_name, spawn_pos.x, spawn_pos.y])

## Boss 恢复独立护盾吸收层
func _boss_regen_shield(amount: int) -> void:
	if boss_unit and boss_unit.is_alive:
		var restored := boss_unit.restore_shield(amount)
		if restored > 0:
			_log("Boss %s 恢复 %d 护盾（%d/%d）" % [
				boss_unit.unit_name,
				restored,
				boss_unit.current_shield,
				boss_unit.max_shield,
			])
			_update_unit_sprite_pos(boss_unit)
			if selected_unit == boss_unit:
				hud.update_unit_info(boss_unit)
			hud.update_objective(_get_objective_text())

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
	# 回合上限由 mos 根据 level_config 和 mission_type 计算
	if mission_objective_state:
		turn_manager.max_turns = mission_objective_state.max_turns
	else:
		turn_manager.max_turns = int(level_config.get("max_turns", 20))
	# 胜利和失败检查通过 Callable 设置

## ===== 渲染 =====

func _render_map() -> void:
	# 清除旧渲染
	for child in map_layer.get_children():
		child.queue_free()

	var base_terrain = map_data.layers.base_terrain
	var blocker = map_data.layers.blocker
	var environment: Dictionary = map_data.get("environment", {})
	var environment_kit := String(environment.get("kit", ""))
	var floor_overrides: Dictionary = {}
	for override in environment.get("floor_variant_overrides", []):
		floor_overrides[Vector2i(int(override.get("x", 0)), int(override.get("y", 0)))] = int(override.get("variant", 0))

	for y in range(map_height):
		for x in range(map_width):
			var terrain = base_terrain[y][x]
			var block = blocker[y][x]
			var pos := Vector2i(x, y)
			var floor_variant := int(floor_overrides.get(pos, _get_environment_variant(pos, "floor", 8)))
			var blocker_variant := _get_blocker_variant(pos, block)
			var edge_variants := _get_terrain_edge_variants(pos, int(terrain))
			_draw_tactical_tile(pos, terrain, block, "", environment_kit, floor_variant, edge_variants, blocker_variant)

	_render_environment_decorations(environment_kit, environment.get("decorations", []))
	_render_network_nodes()

	# 标记撤离点、目标和终端
	for obj in map_data.objects:
		if obj.type == "evac":
			_draw_tactical_tile(Vector2i(obj.x, obj.y), -1, 0, "evac")
		elif obj.type == "destructible_target":
			_draw_tactical_tile(Vector2i(obj.x, obj.y), -1, 0, "destructible_target")
		elif obj.type == "terminal":
			_draw_tactical_tile(Vector2i(obj.x, obj.y), -1, 0, "terminal")
		elif obj.type == "resource":
			_draw_tactical_tile(Vector2i(obj.x, obj.y), -1, 0, "resource")
	_render_evac_zone()


## 常驻撤离区域提示，既标出队伍可分散站立的位置，也不阻挡地图点击。
func _render_evac_zone() -> void:
	_clear_layer(evac_zone_layer)
	if not mission_type in ["extract", "steal_data", "escort", "infiltrate"]:
		return
	for cell in evac_cells:
		if cell != evac_point:
			_highlight_cell(evac_zone_layer, cell, Color(0.0, 0.88, 0.72, 0.18))


## 同步战场可视区与 HUD，确保右侧单位面板不会遮住可操作区域。
func _configure_viewport_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var top_hud_height := hud.get_top_bar_height()
	var bottom_hud_height := 60.0
	var right_panel_width := 250.0
	hud.apply_viewport_layout(Vector2i(viewport_size))
	var map_bounds := Rect2(
		Vector2.ONE * -MAP_VISUAL_MARGIN,
		Vector2(map_width * CELL_SIZE, map_height * CELL_SIZE) + Vector2.ONE * MAP_VISUAL_MARGIN * 2.0
	)
	var safe_viewport := Rect2(
		Vector2(0.0, top_hud_height),
		Vector2(maxf(1.0, viewport_size.x - right_panel_width), maxf(1.0, viewport_size.y - top_hud_height - bottom_hud_height))
	)
	camera.configure_bounds(map_bounds, safe_viewport, get_player_deployment_center())
	RenderingServer.set_default_clear_color(Color(0.015, 0.028, 0.042))
## Task 5: 杩斿洖鐜╁閮ㄧ讲涓績鐨勪笘鐣屽潗鏍囷紝鐢ㄤ簬鐩告満鍒濆鑱氱劍
func get_player_deployment_center() -> Vector2:
	if player_units.is_empty():
		return Rect2(Vector2.ZERO, Vector2(map_width, map_height) * CELL_SIZE).get_center()
	var total := Vector2.ZERO
	for unit in player_units:
		total += _get_cell_center(unit.grid_pos)
	return total / float(player_units.size())

func _render_units() -> void:
	for child in unit_layer.get_children():
		child.queue_free()

	for unit in player_units:
		_create_unit_sprite(unit)

	for unit in enemy_units:
		_create_unit_sprite(unit)

func _create_unit_sprite(unit: Unit) -> void:
	var sprite := UnitSprite.new()
	sprite.name = "Unit_%s_%s" % [unit.team, unit.unit_name]
	sprite.update_unit(unit)
	sprite.position = _get_cell_center(unit.grid_pos)
	unit_layer.add_child(sprite)
	unit.ap_changed.connect(_on_unit_ap_changed)
	unit.unit_died.connect(_on_unit_died)
	unit.unit_damaged.connect(_on_unit_damaged)

func _draw_cell_on(layer: Node2D, pos: Vector2i, color: Color) -> void:
	var rect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(CELL_SIZE, CELL_SIZE)
	rect.position = GridSystem.grid_to_world(pos)
	# Tactical overlays are visual only. They must never consume map clicks.
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)

func _draw_tactical_tile(
	pos: Vector2i,
	terrain: int,
	block: int = 0,
	objective: String = "",
	environment_kit: String = "",
	floor_variant: int = 0,
	edge_variants: Array = [],
	blocker_variant: int = 0
) -> void:
	var tile := TacticalTile.new()
	tile.name = "Tile_%d_%d" % [pos.x, pos.y] if terrain >= 0 else "Objective_%s_%d_%d" % [objective, pos.x, pos.y]
	tile.position = GridSystem.grid_to_world(pos)
	tile.setup(terrain, block, objective, environment_kit, floor_variant, edge_variants, blocker_variant)
	map_layer.add_child(tile)

func _get_environment_variant(pos: Vector2i, component_type: String, count: int) -> int:
	if count <= 0:
		return 0
	return posmod(hash("%s:%s:%d:%d:%d" % [GameManager.current_level_id, component_type, map_data.get("seed", 0), pos.x, pos.y]), count)

func _get_blocker_variant(pos: Vector2i, blocker: int) -> int:
	if blocker == 6:
		return _get_environment_variant(pos, "full_cover", 2)
	if blocker != 0:
		return 2 + _get_environment_variant(pos, "half_cover", 4)
	return 0

func _get_terrain_edge_variants(pos: Vector2i, terrain: int) -> Array:
	var edges: Array = []
	var boundaries := [false, false, false, false]
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for index in range(directions.size()):
		var neighbor: Vector2i = pos + directions[index]
		boundaries[index] = not GridSystem.is_in_bounds(neighbor, map_width, map_height) or MapLoader.get_terrain_at(map_data, neighbor.x, neighbor.y) != terrain
		if boundaries[index]:
			edges.append(index)
	if boundaries[0] and boundaries[3]: edges.append(4)
	if boundaries[0] and boundaries[1]: edges.append(5)
	if boundaries[2] and boundaries[1]: edges.append(6)
	if boundaries[2] and boundaries[3]: edges.append(7)
	return edges

func _render_environment_decorations(environment_kit: String, decorations: Array) -> void:
	if environment_kit.is_empty():
		return
	var type_counts: Dictionary = {}
	for decoration in decorations:
		var component_type := String(decoration.get("component_type", ""))
		var variant := int(decoration.get("variant", 0))
		var texture := ArtCatalog.get_environment_component_texture(environment_kit, component_type, variant)
		if not texture:
			continue
		var instance_index := int(type_counts.get(component_type, 0))
		type_counts[component_type] = instance_index + 1
		var sprite := Sprite2D.new()
		sprite.name = "Environment_%s_%d" % [component_type, instance_index]
		sprite.texture = texture
		sprite.centered = false
		var requested_position := GridSystem.grid_to_world(Vector2i(int(decoration.get("x", 0)), int(decoration.get("y", 0))))
		# Large landmarks are anchored to a grid cell but must stay inside the
		# map rectangle so hidden props cannot spill beyond the fog boundary.
		var map_size := Vector2(map_width * CELL_SIZE, map_height * CELL_SIZE)
		var max_position := Vector2(
			maxf(0.0, map_size.x - texture.get_size().x),
			maxf(0.0, map_size.y - texture.get_size().y)
		)
		sprite.position = Vector2(
			clampf(requested_position.x, 0.0, max_position.x),
			clampf(requested_position.y, 0.0, max_position.y)
		)
		sprite.z_index = int(decoration.get("z", 0))
		map_layer.add_child(sprite)

## 渲染网络节点精灵（在地图上显示设施图标）
## CH1-060: 同时绘制连接线和状态形状，用颜色+形状区分四种节点状态。
func _render_network_nodes() -> void:
	# 清除旧精灵、形状和连接线
	for sprite in _network_node_sprites.values():
		if is_instance_valid(sprite):
			sprite.queue_free()
	_network_node_sprites.clear()
	for shape in _network_shape_nodes.values():
		if is_instance_valid(shape):
			shape.queue_free()
	_network_shape_nodes.clear()
	for line in _network_connection_lines:
		if is_instance_valid(line):
			line.queue_free()
	_network_connection_lines.clear()
	if not tactical_network_state:
		return
	var overlay_vis: bool = hud.is_network_overlay_visible() if hud else false
	var nodes = tactical_network_state.get_all_nodes()
	# CH1-060: Draw connection lines between linked nodes (only when overlay is visible).
	var connections: Array = tactical_network_state.get_connections()
	for conn in connections:
		var from_id: String = String(conn.get("from", ""))
		var to_id: String = String(conn.get("to", ""))
		var from_pos: Vector2i = tactical_network_state.get_node_position(from_id)
		var to_pos: Vector2i = tactical_network_state.get_node_position(to_id)
		if from_pos.x < 0 or to_pos.x < 0:
			continue
		var line := Line2D.new()
		line.name = "NetworkConn_%s_%s" % [from_id, to_id]
		line.add_point(_get_cell_center(from_pos))
		line.add_point(_get_cell_center(to_pos))
		line.width = 2.0
		line.set_meta("from_pos", from_pos)
		line.set_meta("to_pos", to_pos)
		# Color connections by the source node's state.
		var from_state: String = tactical_network_state.get_node_state(from_id)
		match from_state:
			"enemy":
				line.default_color = Color(1.0, 0.4, 0.4, 0.6)
			"player":
				line.default_color = Color(0.4, 1.0, 0.9, 0.7)
			"damaged":
				line.default_color = Color(0.5, 0.5, 0.5, 0.3)
			_:
				line.default_color = Color(0.7, 0.7, 0.7, 0.5)
		line.z_index = 4
		line.visible = overlay_vis and _network_cell_is_observed(from_pos) and _network_cell_is_observed(to_pos)
		map_layer.add_child(line)
		_network_connection_lines.append(line)
	# CH1-060: Draw node sprites with state shape indicators.
	for node_id in nodes:
		var node = nodes[node_id]
		var node_type = String(node.get("type", ""))
		var state = String(node.get("state", "neutral"))
		var pos = tactical_network_state.get_node_position(node_id)
		var world_pos := _get_cell_center(pos)
		# CH1-060: Draw a state shape behind the icon to distinguish states by shape.
		var shape := Polygon2D.new()
		shape.name = "NetworkShape_%s" % node_id
		shape.z_index = 4
		shape.visible = overlay_vis and _network_cell_is_observed(pos)
		var shape_color := Color.WHITE
		var half := float(CELL_SIZE) * 0.28
		match state:
			"enemy":
				# Square for enemy-owned
				shape.polygon = PackedVector2Array([
					Vector2(-half, -half), Vector2(half, -half),
					Vector2(half, half), Vector2(-half, half)
				])
				shape_color = Color(1.0, 0.35, 0.35, 0.55)
			"player":
				# Diamond for player-owned
				shape.polygon = PackedVector2Array([
					Vector2(0, -half), Vector2(half, 0),
					Vector2(0, half), Vector2(-half, 0)
				])
				shape_color = Color(0.35, 1.0, 0.9, 0.55)
			"damaged":
				# X shape for damaged (two crossed rectangles approximated by thin polygons)
				shape.polygon = PackedVector2Array([
					Vector2(-half, -half), Vector2(-half + 3, -half),
					Vector2(half, half), Vector2(half - 3, half)
				])
				shape_color = Color(0.5, 0.5, 0.5, 0.4)
			_:
				# Circle (approximated) for neutral
				var pts := PackedVector2Array()
				var segs := 12
				for i in range(segs):
					var a := TAU * float(i) / float(segs)
					pts.append(Vector2(cos(a) * half, sin(a) * half))
				shape.polygon = pts
				shape_color = Color(0.7, 0.7, 0.7, 0.4)
		shape.color = shape_color
		shape.position = world_pos
		map_layer.add_child(shape)
		_network_shape_nodes[node_id] = shape
		# Node icon sprite
		var texture = ArtCatalog.get_texture(&"network_node", StringName(node_type))
		if texture:
			var sprite = Sprite2D.new()
			sprite.name = "NetworkNode_%s" % node_id
			sprite.texture = texture
			sprite.centered = true
			sprite.position = world_pos
			sprite.z_index = 5
			sprite.visible = overlay_vis and _network_cell_is_observed(pos)
			match state:
				"enemy":
					sprite.modulate = Color(1.0, 0.4, 0.4)
				"player":
					sprite.modulate = Color(0.4, 1.0, 0.9)
				"damaged":
					sprite.modulate = Color(0.5, 0.5, 0.5, 0.6)
				_:
					sprite.modulate = Color(0.9, 0.9, 0.9)
			map_layer.add_child(sprite)
			_network_node_sprites[node_id] = sprite

## 更新网络节点精灵可见性（G 键切换时调用）
## CH1-060: 同时切换连接线和状态形状的可见性。
func _update_network_node_visibility() -> void:
	var vis = hud.is_network_overlay_visible() if hud else false
	for node_id in _network_node_sprites.keys():
		var pos: Vector2i = tactical_network_state.get_node_position(String(node_id)) if tactical_network_state else Vector2i(-1, -1)
		var node_visible := vis and _network_cell_is_observed(pos)
		var sprite = _network_node_sprites[node_id]
		if is_instance_valid(sprite):
			sprite.visible = node_visible
	for node_id in _network_shape_nodes.keys():
		var pos: Vector2i = tactical_network_state.get_node_position(String(node_id)) if tactical_network_state else Vector2i(-1, -1)
		var node_visible := vis and _network_cell_is_observed(pos)
		var shape = _network_shape_nodes[node_id]
		if is_instance_valid(shape):
			shape.visible = node_visible
	for line in _network_connection_lines:
		if is_instance_valid(line):
			var from_pos: Vector2i = line.get_meta("from_pos", Vector2i(-1, -1))
			var to_pos: Vector2i = line.get_meta("to_pos", Vector2i(-1, -1))
			line.visible = vis and _network_cell_is_observed(from_pos) and _network_cell_is_observed(to_pos)

func _network_cell_is_observed(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.y < 0:
		return false
	return visibility_state == null or visibility_state.is_cell_observed(pos)

func _highlight_cell(layer: Node2D, pos: Vector2i, color: Color) -> void:
	var rect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
	rect.position = GridSystem.grid_to_world(pos) + Vector2(1, 1)
	# Reachable/attack/path highlights sit above the map, so make them click-through.
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)

## 范围格使用“填充 + 边框”双重编码，避免玩家只能靠颜色猜动作类型。
func _highlight_range_cell(layer: Node2D, pos: Vector2i, fill_color: Color, border_color: Color, border_width: int = 2) -> void:
	var origin := GridSystem.grid_to_world(pos)

	var inner := ColorRect.new()
	inner.color = fill_color
	inner.position = origin + Vector2(border_width, border_width)
	inner.size = Vector2(CELL_SIZE - border_width * 2, CELL_SIZE - border_width * 2)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(inner)

	var edges := [
		{&"position": origin, &"size": Vector2(CELL_SIZE, border_width)},
		{&"position": origin + Vector2(0, CELL_SIZE - border_width), &"size": Vector2(CELL_SIZE, border_width)},
		{&"position": origin, &"size": Vector2(border_width, CELL_SIZE)},
		{&"position": origin + Vector2(CELL_SIZE - border_width, 0), &"size": Vector2(border_width, CELL_SIZE)},
	]
	for edge_data in edges:
		var edge := ColorRect.new()
		edge.color = border_color
		edge.position = edge_data[&"position"]
		edge.size = edge_data[&"size"]
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(edge)

func _highlight_edge_color(color: Color, alpha: float = 0.9) -> Color:
	return Color(color.r, color.g, color.b, alpha)

func _clear_layer(layer: Node2D) -> void:
	for child in layer.get_children():
		child.queue_free()

## 将规则层的地面效果投影为战场格面，保留普通命中/爆炸特效节点。
func _render_ground_effects() -> void:
	for child in effect_layer.get_children():
		if child.name.begins_with("GroundEffect_"):
			child.queue_free()
	for effect_data in action_system.ground_effects:
		var pos: Vector2i = effect_data.get("pos", Vector2i.ZERO)
		var kind := String(effect_data.get("type", ""))
		var overlay := Polygon2D.new()
		overlay.name = "GroundEffect_%d_%d_%s" % [pos.x, pos.y, kind]
		overlay.position = GridSystem.grid_to_world(pos)
		overlay.polygon = PackedVector2Array([
			Vector2(4, 4), Vector2(CELL_SIZE - 4, 4),
			Vector2(CELL_SIZE - 4, CELL_SIZE - 4), Vector2(4, CELL_SIZE - 4)
		])
		match kind:
			"fire": overlay.color = Color(1.0, 0.27, 0.05, 0.46)
			"heal_mist": overlay.color = Color(0.16, 0.92, 0.58, 0.36)
			_: overlay.color = Color(0.58, 0.74, 0.84, 0.30)
		effect_layer.add_child(overlay)

## ===== 战斗流程 =====

func _start_battle() -> void:
	if boss_unit:
		AudioManager.bgm_boss()
	else:
		AudioManager.bgm_battle_layer(alert_state.get_alert_level() if alert_state else AlertState.LEVEL_CALM)
	# CH1-080: 初始化遭遇区为 zone_a（玩家出生点所在的第一个区域）
	current_encounter_id = "zone_a"
	# 每关使用独立基础上限，再应用难度加成（故事+5，困难-3）。
	var diff_params = GameManager.get_difficulty_params()
	var base_turn_limit := mission_objective_state.max_turns if mission_objective_state else int(level_config.get("max_turns", 20))
	var turn_limit = base_turn_limit + int(diff_params.get("turn_limit_bonus", 0))
	turn_limit = max(5, turn_limit)  # 最低 5 回合
	turn_manager.setup(player_units, enemy_units, turn_limit)
	action_system.set_units(player_units, enemy_units)
	# CODE-P2-02: Setup tactical network from map data
	# CH1-060: Pass connections so power conduits link to facilities and overlay renders links.
	if tactical_network_state and not map_data.is_empty():
		var nodes: Array = map_data.get("nodes", [])
		var connections: Array = map_data.get("connections", [])
		tactical_network_state.setup(nodes, connections)
		_render_network_nodes()
	# 根据关卡配置设置增援上限（防止无限刷怪）
	enemy_director.max_reinforcements = int(level_config.get("max_reinforcements", 20))
	enemy_director.enemy_cap_per_wave = int(level_config.get("enemy_cap", 12))
	hud.set_battle_controller(self)
	turn_manager.start_battle()
	hud.update_objective(_get_objective_text())
	hud.update_turn_display(1, TurnManager.TurnPhase.PLAYER_ACTION)
	# Keep the first actionable frame self-explanatory; calm alert is still useful
	# context when the player has not triggered any alarm yet.
	hud.update_alert_display(alert_state)
	_log("战斗开始！难度=%s 回合上限=%d" % [GameManager.get_settings().get("difficulty", "standard"), turn_limit])
	# CH1-030: 战斗开始后启动上下文教学提示序列
	_begin_context_tutorials()

func _get_objective_text() -> String:
	var objective_text := "目标：消灭所有敌人"
	if mission_objective_state:
		objective_text = mission_objective_state.get_status_text()
	if boss_unit and boss_unit.is_alive and not boss_phases.is_empty():
		var phase_idx := clampi(boss_current_phase, 0, boss_phases.size() - 1)
		var phase_name := String(boss_phases[phase_idx].get("name", "阶段%d" % (phase_idx + 1)))
		return "Boss %s [%s] · HP %d/%d · 护盾 %d/%d | %s" % [
			boss_unit.unit_name,
			phase_name,
			boss_unit.current_hp,
			boss_unit.max_hp,
			boss_unit.current_shield,
			boss_unit.max_shield,
			objective_text,
		]
	return objective_text

func _check_victory() -> bool:
	if mission_objective_state:
		return mission_objective_state.is_victory()
	return enemy_units.filter(func(u): return u.is_alive).is_empty()

func _check_defeat() -> bool:
	if mission_objective_state:
		return mission_objective_state.is_defeat()
	return player_units.filter(func(u): return u.is_alive).is_empty()

## ===== 回合回调 =====

func _on_phase_changed(phase: TurnManager.TurnPhase) -> void:
	match phase:
		TurnManager.TurnPhase.PLAYER_ACTION:
			hud.update_turn_display(turn_manager.turn_number, phase)
			turn_manager.input_locked = false
			hud.set_buttons_disabled(false)
			action_system.process_ground_effects_on_turn_start()
			# CODE-P2-02: Decay alert at turn boundary
			if alert_state:
				alert_state.on_turn_end()
			hud.update_alert_display(alert_state)
			_update_visibility()
			# CH1-050: Freeze intents for enemies that left sight during the
			# enemy turn. Stale intents remain visible (marked outdated) so the
			# player can still read the last known plan, but no longer leak
			# real-time information.
			if enemy_intent_state:
				enemy_intent_state.freeze_stale_intents()
			_refresh_enemy_intent_display()
			_auto_select_player_unit()
			if mission_objective_state:
				mission_objective_state.apply_event(&"turn_started", {"turn": turn_manager.turn_number, "team": "player"})
			hud.update_objective(_get_objective_text())
			_log("第 %d 回合 - 玩家行动" % turn_manager.turn_number)

		TurnManager.TurnPhase.ENEMY_ACTION:
			hud.update_turn_display(turn_manager.turn_number, phase)
			turn_manager.input_locked = true
			hud.set_buttons_disabled(true)
			if mission_objective_state:
				mission_objective_state.apply_event(&"turn_started", {"turn": turn_manager.turn_number, "team": "enemy"})
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
	# CH1-060: Sync beacon delay bonus from disabled beacons to delay reinforcements.
	if tactical_network_state:
		enemy_director.reinforcement_delay_bonus = tactical_network_state.get_reinforcement_delay_bonus()
	# 检查增援触发：信号 reinforcement_spawned 驱动单位生成（见 _on_reinforcement_spawned）
	enemy_director.on_turn_start(turn_number)
	# 同步 action_system 的单位列表（增援可能已加入）
	action_system.set_units(player_units, enemy_units)

## 实际生成增援敌人单位并加入战斗
## 出生点选择：优先使用脚本中指定的 position，否则在地图边缘找空位
## CODE-CH1-020: 增援单位使用 trigger_id + index 派生稳定 ID，保证同一触发多次重试产生相同身份。
func _spawn_reinforcement_units(units_data: Array, trigger_id: String = "") -> void:
	for i in range(units_data.size()):
		var unit_data = units_data[i]
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
		# CODE-CH1-020: 优先使用脚本提供的 id；否则用 trigger_id+index 派生；最后回退到 team_index
		var stable_id: String = String(unit_data.get("id", ""))
		if stable_id == "":
			# 从 unit_data 提取 EnemyDirector 注入的 trigger_id
			var trig: String = String(unit_data.get("trigger_id", trigger_id))
			if trig != "":
				stable_id = "reinforce_%s_%d" % [trig, i]
			else:
				stable_id = "%s_%d" % [unit.team, enemy_units.size()]
		unit.entity_id = stable_id
		_apply_difficulty_to_enemy(unit)
		enemy_units.append(unit)
		# 渲染新单位精灵
		_create_unit_sprite(unit)
		_log("增援到达：%s (%d,%d)" % [unit.unit_name, spawn_pos.x, spawn_pos.y])

## 增援信号回调：实际生成增援单位并记录日志
## 由 EnemyDirector.reinforcement_spawned 驱动，回合触发和事件触发共用此路径
func _on_reinforcement_spawned(units_data: Array, message: String) -> void:
	_spawn_reinforcement_units(units_data)
	if message != "":
		_log(message)

## 玩家增援信号回调：生成玩家单位，不占用敌人增援上限
## 由 EnemyDirector.player_reinforcement_spawned 驱动
func _on_player_reinforcement_spawned(units_data: Array, message: String) -> void:
	_spawn_player_units(units_data)
	if message != "":
		_log(message)

## 生成玩家增援单位并加入战斗
## 出生点选择：优先使用脚本中指定的 position，否则跳过
## CODE-CH1-020: 玩家增援同样使用 trigger_id+index 派生稳定 ID。
func _spawn_player_units(units_data: Array) -> void:
	for i in range(units_data.size()):
		var unit_data = units_data[i]
		var unit_type = unit_data.get("type", "assault")
		var pos_arr = unit_data.get("position", [0, 0])
		var spawn_pos = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
		# 若指定位置被占或越界，跳过本次增援
		if not GridSystem.is_in_bounds(spawn_pos, map_width, map_height):
			continue
		if _get_unit_at(spawn_pos) != null:
			continue
		var unit = GameData.create_player_unit(unit_type, _get_job_display_name(unit_type))
		unit.grid_pos = spawn_pos
		unit.height = MapLoader.get_height_at(map_data, spawn_pos.x, spawn_pos.y)
		# CODE-CH1-020: 优先使用脚本提供的 id；否则用 trigger_id+index 派生
		var stable_id: String = String(unit_data.get("id", ""))
		if stable_id == "":
			var trig: String = String(unit_data.get("trigger_id", ""))
			if trig != "":
				stable_id = "reinforce_%s_%d" % [trig, i]
			else:
				stable_id = "%s_%d" % [unit.team, player_units.size()]
		unit.entity_id = stable_id
		unit.current_ap = unit.max_ap
		player_units.append(unit)
		_create_unit_sprite(unit)
		_log("玩家增援到达：%s (%d,%d)" % [unit.unit_name, spawn_pos.x, spawn_pos.y])

## CODE-P2-02: 网络操作触发的警报请求
func _on_network_alert_requested(amount: int, reason: String) -> void:
	if alert_state:
		alert_state.apply_event(reason)
		hud.update_alert_display(alert_state)
		_log("警报事件: %s (amount=%d)" % [reason, amount])

func _on_alert_level_changed(_old_level: int, new_level: int) -> void:
	if boss_unit:
		return
	AudioManager.bgm_battle_layer(new_level)

## 网络操作完成回调：将相机接管等事件桥接为 mission_event
## 相机接管触发 player_reinforcement 脚本（scout rescue）
## CH1-040: 相机接管同时注册持久摄像头区域，维持观察区直到相机被禁用或过载。
## CH1-060: 门/炮塔/电力/信标操作现在都有明确的战术反馈。
func _on_network_operation(node_id: String, operation: String, result: Dictionary) -> void:
	if not is_instance_valid(mission_objective_state):
		return
	var node_type: String = ""
	if tactical_network_state:
		var nodes = tactical_network_state.get_all_nodes()
		var node = nodes.get(node_id, {})
		node_type = String(node.get("type", ""))
	# CH1-060: Spawn network operation VFX at the node position.
	var node_pos: Vector2i = tactical_network_state.get_node_position(node_id) if tactical_network_state else Vector2i(-1, -1)
	if node_pos.x >= 0:
		match operation:
			"takeover":
				_spawn_effect("network_takeover", node_pos)
			"disable":
				_spawn_effect("network_disable", node_pos)
			"overload":
				_spawn_effect("network_overload", node_pos)
				# Overload also creates a hazard explosion at the node.
				_spawn_effect("explosion", node_pos)
	# 相机接管：触发 scout rescue 事件增援
	if operation == "takeover" and node_type == "camera":
		var event_name = &"camera_takeover"
		mission_objective_state.mission_event.emit(event_name, {"node_id": node_id})
		_log("相机接管完成，评估事件增援")
	# CH1-040: 相机接管注册持久观察区；禁用/过载移除该区域。
	var reveal_cells: Array = result.get("reveal_cells", [])
	if reveal_cells.size() > 0 and visibility_state:
		match operation:
			"takeover":
				var zone_id := "camera_%s" % node_id
				visibility_state.add_camera_zone(zone_id, reveal_cells)
				_sync_camera_zone_cells()
				_log("相机接管揭示 %d 个格子（持久观察区）" % reveal_cells.size())
			"disable", "overload":
				var zone_id := "camera_%s" % node_id
				visibility_state.remove_camera_zone(zone_id)
				_sync_camera_zone_cells()
				_log("相机失效，观察区收回为已记录：%s" % operation)
			_:
				visibility_state.reveal_cells(reveal_cells)
				_log("揭示 %d 个格子" % reveal_cells.size())
		if visibility_renderer:
			visibility_renderer.refresh()
		_refresh_last_known_ghosts()
	# CH1-060: Door operations change pathfinding; refresh node sprites to show new state.
	if node_type == "door":
		match operation:
			"takeover":
				_log("门 %s 已开启，路线可通行" % node_id)
			"disable":
				_log("门 %s 已禁用，永久关闭" % node_id)
			"overload":
				_log("门 %s 已过载，永久卡死并产生危害" % node_id)
	# CH1-060: Turret ownership change; player turrets fire next enemy turn.
	if node_type == "turret":
		match operation:
			"takeover":
				_log("炮塔 %s 已接管，下个敌回合自动射击" % node_id)
			"disable":
				_log("炮塔 %s 已禁用，停止射击" % node_id)
			"overload":
				_log("炮塔 %s 已过载，爆炸损毁" % node_id)
	# CH1-060: Power conduit cascade; connected facilities lose power.
	if node_type == "power_conduit":
		var disabled: Array = result.get("facilities_disabled", [])
		if not disabled.is_empty():
			_log("电力 %s %s：%d 个关联设施断电" % [node_id, operation, disabled.size()])
	# CH1-060: Beacon delay; reinforcements pushed back.
	if node_type == "reinforcement_beacon":
		match operation:
			"disable":
				_log("信标 %s 已禁用，增援延迟 +2 回合" % node_id)
			"overload":
				_log("信标 %s 已过载，永久摧毁" % node_id)
			"takeover":
				_log("信标 %s 已接管，增援被阻止" % node_id)
	# CH1-060: Refresh network node sprites to reflect the new state.
	_render_network_nodes()

## CH1-040: 重新收集所有活跃摄像头区域格子，同步给渲染器。
func _sync_camera_zone_cells() -> void:
	_camera_zone_cells.clear()
	if not visibility_state:
		return
	var zones: Dictionary = visibility_state._camera_zones
	for zone_id in zones.keys():
		for cell in zones[zone_id]:
			if not _camera_zone_cells.has(cell):
				_camera_zone_cells.append(cell)

## CODE-P2-02: G 键切换网络覆盖层可视化，不影响任何游戏状态
func _on_toggle_network() -> void:
	if tactical_network_state:
		tactical_network_state.toggle_overlay()
	if hud:
		hud.toggle_network_overlay()
		_update_network_node_visibility()
		_log("网络覆盖层: %s" % ("显示" if hud.is_network_overlay_visible() else "隐藏"))
	# CH1-090: Scan VFX plays at the selected unit or map center.
	var scan_pos: Vector2i = selected_unit.grid_pos if selected_unit else Vector2i(map_width / 2, map_height / 2)
	_spawn_effect("scan", scan_pos)
	_advance_context_hint("network")

## 任务事件桥接：接收 mission_event，更新存活计数并交由 EnemyDirector 评估事件增援
## 单位生成由 reinforcement_spawned 信号统一驱动，这里不直接 spawn
func _on_mission_event(event_name: StringName, payload: Dictionary) -> void:
	if not is_instance_valid(mission_objective_state):
		return
	# 更新存活计数，让事件增援遵循上限
	var alive_p = 0
	var alive_e = 0
	for u in player_units:
		if u and u.is_alive:
			alive_p += 1
	for u in enemy_units:
		if u and u.is_alive:
			alive_e += 1
	if enemy_director:
		enemy_director.set_alive_counts(alive_p, alive_e)
		enemy_director.on_event(event_name)
		action_system.set_units(player_units, enemy_units)
	# 刷新目标文本（阶段变化、上传进度等）
	hud.update_objective(mission_objective_state.get_status_text())

## 敌人回合结束时推进上传进度（infiltrate 三阶段流）
func _advance_upload_progress() -> void:
	if not mission_objective_state:
		return
	var upload_result := mission_objective_state.apply_event(&"enemy_turn_completed", {})
	if upload_result.get("changed", false):
		hud.update_objective(mission_objective_state.get_status_text())
		# CH1-090: Upload VFX on the active terminal to visualise progress.
		if terminals.size() > 0:
			_spawn_effect("upload", terminals[0])
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
	AudioManager.sfx_victory()
	AudioManager.bgm_victory()
	_finish_battle(true, result)

func _on_battle_lost(result: Dictionary) -> void:
	_log("失败...")
	AudioManager.sfx_defeat()
	AudioManager.bgm_defeat()
	_finish_battle(false, result)

func _finish_battle(victory: bool, result: Dictionary) -> void:
	await get_tree().create_timer(1.5).timeout

	var survived = player_units.filter(func(u): return u.is_alive).size()
	var total = player_units.size()

	# Task 3: use mission_objective_state modifiers and unified star calculation
	var modifiers := {}
	if mission_objective_state:
		modifiers = mission_objective_state.get_result_modifiers()
	var optional_required := bool(level_config.get("three_star_requires_optional", false))
	var optional_complete := not optional_required or bool(modifiers.get("optional_resource_collected", false))
	var stars = _calculate_stars(
		victory,
		survived,
		total,
		turn_manager.turn_number,
		optional_complete
	)

	var optional_credit := int(modifiers.get("optional_credit", 0))
	var level_rewards = level_config.get("rewards", {})
	var diff_params = GameManager.get_difficulty_params()
	var reward_mult = float(diff_params.get("reward_multiplier", 1.0))
	var rewards = {
		"credit": int(round(level_rewards.get("credit", 200) * reward_mult)) + (optional_credit if victory else 0),
		"exp": int(round(level_rewards.get("exp", 150) * reward_mult)),
		"intel": 0,
	}

	# CH1-080: 失败原因和遭遇检查点可用性
	var defeat_reason := String(result.get("reason", ""))
	var has_encounter_checkpoint := not victory and current_encounter_id != "" and current_encounter_id != "zone_a"

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
		"optional_credit": optional_credit if victory else 0,
		"optional_resource_collected": bool(modifiers.get("optional_resource_collected", false)),
		"defeat_reason": defeat_reason,
		"has_encounter_checkpoint": has_encounter_checkpoint,
		"encounter_id": current_encounter_id,
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
	# 特殊规则：首回合敌人被动（enemy_passive_turn_1）
	if mission_objective_state and mission_objective_state.is_enemy_passive(turn_manager.turn_number):
		_log("敌人本回合待命（特殊规则）")
		if not turn_manager.battle_over:
			_advance_upload_progress()
			turn_manager.end_enemy_turn()
		return
	# 敌人回合开始时处理 Boss 专属能力（召唤、护盾恢复等）
	_process_boss_abilities()
	# CH1-060: Player-owned turrets fire at enemies in range before enemies act.
	_fire_player_turrets()
	for enemy in enemy_units:
		if not enemy.is_alive:
			continue
		if turn_manager.battle_over:
			break
		await _execute_enemy_action(enemy)
		await get_tree().create_timer(0.3).timeout

	if not turn_manager.battle_over:
		_advance_upload_progress()
		turn_manager.end_enemy_turn()

## CH1-060: Player-owned turrets automatically fire at the nearest enemy in range
## at the start of the enemy turn. Each turret fires once per turn if it has a
## valid target and is powered (facility available).
func _fire_player_turrets() -> void:
	if not tactical_network_state:
		return
	var turrets: Array = tactical_network_state.get_player_turrets()
	for turret in turrets:
		var turret_pos: Vector2i = turret.get("pos", Vector2i(-1, -1))
		var turret_range: int = int(turret.get("range", 5))
		var turret_damage: int = int(turret.get("damage", 3))
		# Find nearest alive enemy in range.
		var best_target: Unit = null
		var best_dist: int = 9999
		for enemy in enemy_units:
			if not enemy or not enemy.is_alive:
				continue
			var dist: int = GridSystem.manhattan_distance(turret_pos, enemy.grid_pos)
			if dist > turret_range:
				continue
			if dist < best_dist:
				best_dist = dist
				best_target = enemy
		if best_target:
			best_target.take_damage(turret_damage)
			_log("炮塔 %s 射击 %s，造成 %d 伤害" % [turret.get("node_id", ""), best_target.unit_name, turret_damage])
			_spawn_effect("hit", best_target.grid_pos)
			# unit_died signal handles death telemetry and sprite update automatically.
			_render_units()
	_check_victory_instant()

func _execute_enemy_action(enemy: Unit) -> void:
	# 每个敌人执行一次行动（攻击或移动），消耗1AP
	if enemy.current_ap <= 0:
		return

	# CH1-050: Prefer the planned action from the public intent preview so the
	# player's observation matches execution. If the plan is missing or no
	# longer valid (e.g. target died), fall back to a fresh UtilityAI decision.
	var action := _consume_planned_action(enemy)

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


## CH1-050: Resolve the planned action for an enemy and consume it from the
## intent state so it is not shown again after execution. If the plan is
## missing or its target is no longer valid, fall back to UtilityAI so the
## enemy still acts deterministically.
func _consume_planned_action(enemy: Unit) -> Dictionary:
	var planned: Dictionary = {}
	if enemy_intent_state and _enemy_intents_planned:
		var stored: Dictionary = enemy_intent_state.get_intent(enemy.entity_id)
		if not stored.is_empty():
			var itype: String = String(stored.get("type", "wait"))
			# Re-resolve attack target from the stored target_pos so the plan
			# stays valid even if the player moved the target unit.
			if itype == "attack":
				var target_pos = stored.get("target_pos", null)
				if target_pos is Vector2i:
					var target_unit = _get_unit_at(target_pos)
					if target_unit and target_unit.is_alive and target_unit.team == "player":
						planned = {
							"type": "attack",
							"target": target_unit,
						}
			elif itype in ["move", "move_to_cover"]:
				var target_pos = stored.get("target_pos", null)
				if target_pos is Vector2i and target_pos.x >= 0:
					planned = {
						"type": itype,
						"target_pos": target_pos,
					}
			elif itype == "overwatch":
				planned = {"type": "overwatch"}
			else:
				planned = {"type": itype}
			# Consume the intent so the renderer does not keep showing it after
			# the enemy has already acted.
			enemy_intent_state.remove_intent(enemy.entity_id)
	if planned.is_empty():
		planned = UtilityAI.decide_action(enemy, player_units, map_data, enemy_units)
	return planned

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
		_update_unit_sprite_pos(enemy, true)
		_log("%s 移动到 (%d,%d)" % [enemy.unit_name, last_pos.x, last_pos.y])

## ===== 玩家输入 =====

func _unhandled_input(event: InputEvent) -> void:
	if turn_manager.input_locked or turn_manager.battle_over:
		return
	if turn_manager.current_phase != TurnManager.TurnPhase.PLAYER_ACTION:
		return

	if event.is_action_pressed("pause"):
		# CH1-030: Esc 只在无目标模式时暂停；否则逐级取消当前动作
		if _has_active_input_mode():
			_cancel_action()
		else:
			_show_pause_menu()
		return

	if event.is_action_pressed("end_turn"):
		_end_player_turn()
		_advance_context_hint("end_turn")
		return

	if event.is_action_pressed("next_unit"):
		_on_next_unit()
		return

	if event.is_action_pressed("toggle_network"):
		_on_toggle_network()
		return

	# 鼠标移动时实时预览移动路径
	if event is InputEventMouseMotion and selected_action == "move" and selected_unit:
		var mouse_motion := event as InputEventMouseMotion
		var motion_world := get_viewport().canvas_transform.affine_inverse() * mouse_motion.position
		_update_path_preview(motion_world)

	if event is InputEventMouseButton and event.pressed:
		var mouse_btn := event as InputEventMouseButton
		var click_world := get_viewport().canvas_transform.affine_inverse() * mouse_btn.position
		print("  [DBG-BATTLE] mouse_btn click at screen=", mouse_btn.position, " world=", click_world, " grid=", GridSystem.world_to_grid(click_world))
		if mouse_btn.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(click_world)
		elif mouse_btn.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(click_world)

## 右键是移动快捷键：点击友军立即显示可达范围；移动模式下再次右键取消。
func _handle_right_click(world_pos: Vector2) -> void:
	var grid_pos := GridSystem.world_to_grid(world_pos)
	var clicked_unit := _get_unit_at(grid_pos) if GridSystem.is_in_bounds(grid_pos, map_width, map_height) else null
	if selected_action == "move":
		_cancel_action()
		return
	if selected_action == "targeting" or (hud._action_picker != null and is_instance_valid(hud._action_picker)):
		_cancel_action()
		return
	if clicked_unit and clicked_unit.is_alive and clicked_unit.team == "player":
		if clicked_unit != selected_unit:
			_select_unit(clicked_unit)
		if selected_unit and selected_unit.current_ap > 0:
			on_move_button()
		return
	if selected_unit and selected_unit.is_alive and selected_unit.team == "player" and selected_action == "":
		on_move_button()
		return
	_cancel_action()

func _handle_left_click(world_pos: Vector2) -> void:
	var grid_pos = GridSystem.world_to_grid(world_pos)
	if not GridSystem.is_in_bounds(grid_pos, map_width, map_height):
		return
	# A teammate click is always a selection change outside explicit skill/item targeting.
	# Without this, a stale move/attack mode silently eats the next unit click.
	var clicked_unit = _get_unit_at(grid_pos)
	if selected_action != "targeting" and clicked_unit and clicked_unit.team == "player" and clicked_unit != selected_unit:
		_select_unit(clicked_unit)
		return

	match selected_action:
		"targeting":
			# 目标选择模式：转发给 TargetingController
			if targeting_controller and targeting_controller.is_active:
				var result = targeting_controller.try_confirm(grid_pos)
				if not result.get("success", false):
					_log("无效目标：%s" % result.get("reason", "unknown"))
			return
		"move":
			# 先检查是否点击了终端（steal_data/infiltrate 任务交互）
			if mission_type in ["steal_data", "infiltrate"] and grid_pos in terminals:
				if selected_unit and selected_unit.team == "player":
					if _try_interact_terminal(selected_unit, grid_pos):
						_show_move_range(selected_unit)
						hud.update_unit_info(selected_unit)
						return
			if grid_pos in resource_positions and selected_unit and selected_unit.team == "player":
				if _try_interact_resource(selected_unit, grid_pos):
					_show_move_range(selected_unit)
					hud.update_unit_info(selected_unit)
					return
			_try_move(grid_pos)
		"attack":
			var target := _get_unit_at(grid_pos)
			if attack_confirmation_required:
				if target and target.team != "player" and target == attack_preview_target:
					_try_attack(grid_pos)
				elif target and target.team != "player" and target in attack_targets:
					_show_attack_preview(target)
				else:
					hud.set_context_prompt("请点击红色目标确认攻击，右键取消")
				return
			_try_attack(grid_pos)
		"":
			# 选择单位
			var unit = _get_unit_at(grid_pos)
			if unit and unit.is_alive and unit.team == "player":
				_select_unit(unit)
			elif unit and unit.is_alive and unit.team != "player" and selected_unit and selected_unit.team == "player":
				_begin_direct_attack_preview(unit)
			else:
				_deselect_unit()

func _select_unit(unit: Unit) -> void:
	_deselect_unit()
	selected_unit = unit
	_update_unit_sprite_selection(unit, true)
	hud.update_unit_info(unit)
	if unit.team == "player":
		hud.set_context_state(HUD.ContextState.UNIT_SELECTED)
		_advance_context_hint("select")
		# CH1-090: Selection VFX confirms the pick.
		_spawn_effect("selection", unit.grid_pos)
	else:
		_advance_context_hint("observe")
	_refresh_selected_unit_affordances(unit)

## 每个玩家回合至少给玩家一个可操作焦点，避免敌方回合后动作条消失。
func _auto_select_player_unit() -> void:
	if selected_unit and selected_unit.is_alive and selected_unit.team == "player":
		return
	for unit in player_units:
		if unit and unit.is_alive and unit.team == "player":
			_select_unit(unit)
			return

func _deselect_unit() -> void:
	# 取消任何进行中的目标选择
	_cancel_targeting_if_active()
	hud.hide_action_picker()
	if selected_unit:
		_update_unit_sprite_selection(selected_unit, false)
	selected_unit = null
	selected_action = ""
	attack_preview_target = null
	attack_preview_data.clear()
	attack_confirmation_required = false
	last_player_attack_result.clear()
	_pending_action_id = ""
	_pending_action_kind = ""
	reachable_cells.clear()
	attack_targets.clear()
	v2_attack_range_cells.clear()
	path_preview.clear()
	_clear_layer(move_highlight)
	_clear_layer(path_preview_layer)
	_clear_layer(attack_highlight)
	if v2_affordance_presenter:
		v2_affordance_presenter.clear_all()
	hud.update_unit_info(null)
	hud.set_action_buttons_visible(false)
	hud.set_context_state(HUD.ContextState.NONE)
	hud.set_targeting_hint("")
	hud.update_objective(_get_objective_text())

## CH1-030: 是否有活跃的目标选择或动作模式（Esc 逐级取消 vs 暂停的判定）
func _has_active_input_mode() -> bool:
	if targeting_controller and targeting_controller.is_active:
		return true
	if hud and hud._action_picker != null and is_instance_valid(hud._action_picker):
		return true
	return selected_action != ""

func _cancel_action() -> void:
	# 优先取消目标选择模式
	if targeting_controller and targeting_controller.is_active:
		targeting_controller.cancel()
		return
	# 取消行动选择面板
	if hud._action_picker != null and is_instance_valid(hud._action_picker):
		hud.hide_action_picker()
		_pending_action_id = ""
		_pending_action_kind = ""
		return
	if selected_action != "":
		selected_action = ""
		attack_preview_target = null
		attack_preview_data.clear()
		attack_confirmation_required = false
		_pending_action_id = ""
		_pending_action_kind = ""
		_clear_layer(attack_highlight)
		_clear_layer(path_preview_layer)
		path_preview.clear()
		if selected_unit:
			hud.update_unit_info(selected_unit)
			_refresh_selected_unit_affordances(selected_unit)
		hud.set_targeting_hint("")
		hud.update_objective(_get_objective_text())
	else:
		_deselect_unit()

## ===== 行动执行 =====

func _highlight_color(role: String, fallback: Color) -> Color:
	return AccessibilitySettings.get_highlight_color(role, fallback)

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
		if not _is_v2_battle():
			var move_color := _highlight_color("move", COLOR_MOVE)
			_highlight_range_cell(move_highlight, cell, move_color, _highlight_edge_color(move_color))

	# 标记选中单位本回合能进入的撤离区域格。
	if mission_type in ["extract", "steal_data", "escort", "infiltrate"]:
		for cell in evac_cells:
			if reachable_cells.has(cell) or unit.grid_pos == cell:
				_highlight_cell(move_highlight, cell, _highlight_color("evac", COLOR_EVAC))

	# 标记终端（steal_data/infiltrate 任务）
	if mission_type in ["steal_data", "infiltrate"]:
		for term_pos in terminals:
			# 终端相邻格可达时高亮终端
			if _is_adjacent_reachable(unit, term_pos):
				_highlight_cell(move_highlight, term_pos, _highlight_color("target", COLOR_TARGET))

## 选中单位后的默认可发现性层：同时展示移动与攻击信息。
## 玩家不需要先找到隐藏的“攻击模式”按钮，红色区域就是当前武器的有效范围。
func _refresh_selected_unit_affordances(unit: Unit) -> void:
	if not unit or not is_instance_valid(unit):
		return
	_show_move_range(unit)
	_clear_layer(attack_highlight)
	attack_targets.clear()
	if unit.team != "player":
		return
	if unit.current_ap <= 0:
		hud.set_context_prompt("蓝色格 = 可移动；本队员没有 AP，无法攻击。按 Tab 选择其他队员，或结束回合。")
		return
	_show_attack_range(unit)
	if _is_v2_battle() and v2_affordance_presenter:
		v2_affordance_presenter.show_for_unit(unit, {"reachable": reachable_cells}, {
			"range_cells": v2_attack_range_cells,
			"targets": attack_targets,
		})
	var min_range := int(unit.weapon_range[0]) if unit.weapon_range.size() > 0 else 1
	var max_range := int(unit.weapon_range[1]) if unit.weapon_range.size() > 1 else min_range
	var range_text := "攻击范围 %d-%d 格" % [min_range, max_range]
	if attack_targets.is_empty():
		hud.set_context_prompt(
			"蓝色格 = 可移动；半透明红色区域 = %s。当前没有可攻击敌人，先移动到射程内或结束回合。" % range_text
		)
	else:
		hud.set_context_prompt(
			"蓝色格 = 可移动；红色敌人 = 可攻击（%s）。点击红色敌人预览命中率/伤害，再次点击确认。" % range_text
		)

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
		var color = _highlight_color("path", COLOR_PATH) if i < path.size() - 1 else _highlight_color("selected", Color(0.1, 1.0, 0.2, 0.45))
		_highlight_cell(path_preview_layer, cell, color)
	# 绘制连接线
	_draw_path_line(path)

## 在路径预览层上绘制途径格之间的连接线
func _draw_path_line(path: Array) -> void:
	if path.size() < 2:
		return
	var line = Line2D.new()
	line.width = 3.0
	line.default_color = _highlight_color("path", Color(0.2, 1.0, 0.3, 0.8))
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
	v2_attack_range_cells.clear()
	var min_range := int(unit.weapon_range[0]) if unit.weapon_range.size() > 0 else 1
	var max_range := int(unit.weapon_range[1]) if unit.weapon_range.size() > 1 else min_range
	# 先显示完整可射击区域，再用更亮的格子标出真实敌人/目标，
	# 让玩家即使暂时没有敌人也能理解武器射程。
	for y in range(maxi(0, unit.grid_pos.y - max_range), mini(map_height, unit.grid_pos.y + max_range + 1)):
		for x in range(maxi(0, unit.grid_pos.x - max_range), mini(map_width, unit.grid_pos.x + max_range + 1)):
			var cell := Vector2i(x, y)
			var dist := GridSystem.manhattan_distance(unit.grid_pos, cell)
			if dist < min_range or dist > max_range:
				continue
			if VisionSystem.has_line_of_sight(unit.grid_pos, cell, map_width, map_height, _is_vision_blocking):
				v2_attack_range_cells.append(cell)
				if not _is_v2_battle():
					var attack_range_color := _highlight_color("attack", COLOR_ATTACK_RANGE)
					_highlight_range_cell(attack_highlight, cell, attack_range_color, _highlight_edge_color(attack_range_color))
	# 敌方单位
	# CH1-040: 只能攻击处于正在观察格子的敌人；隐藏敌人不可被选中
	for enemy in enemy_units:
		if not enemy.is_alive:
			continue
		if visibility_state and not visibility_state.is_cell_observed(enemy.grid_pos):
			continue
		var dist = GridSystem.manhattan_distance(unit.grid_pos, enemy.grid_pos)
		if dist >= min_range and dist <= max_range:
			var has_los = VisionSystem.has_line_of_sight(
				unit.grid_pos, enemy.grid_pos,
				map_width, map_height, _is_vision_blocking
			)
			if has_los:
				attack_targets.append(enemy)
				if not _is_v2_battle():
					var target_color := _highlight_color("attack", COLOR_ATTACK)
					var target_border := _highlight_color("target", Color(1.0, 0.78, 0.16, 0.95))
					_highlight_range_cell(attack_highlight, enemy.grid_pos, target_color, _highlight_edge_color(target_border))
	# 可破坏目标（destroy 任务）
	for tpos in destructible_targets:
		var state = destructible_target_states.get(tpos, {})
		if state.get("destroyed", false):
			continue
		var dist = GridSystem.manhattan_distance(unit.grid_pos, tpos)
		if dist >= min_range and dist <= max_range:
			var has_los = VisionSystem.has_line_of_sight(
				unit.grid_pos, tpos,
				map_width, map_height, _is_vision_blocking
			)
			if has_los:
				attack_targets.append(tpos)  # 混合类型：Unit 和 Vector2i
				if not _is_v2_battle():
					var destructible_color := _highlight_color("target", COLOR_TARGET)
					_highlight_range_cell(attack_highlight, tpos, destructible_color, _highlight_edge_color(destructible_color))

## 直接点击敌人后进入可读的二次确认预览，不执行攻击。
func _begin_direct_attack_preview(target: Unit) -> void:
	if not selected_unit or selected_unit.team != "player":
		return
	on_attack_button()
	attack_confirmation_required = true
	if target in attack_targets:
		_show_attack_preview(target)
	else:
		hud.set_context_prompt("无法攻击 %s：超出射程或没有视线" % target.unit_name)

## 查询当前目标的真实攻击结果参数，并把关键数字放到上下文提示中。
func _show_attack_preview(target: Unit) -> void:
	if not selected_unit or not target or not target.is_alive:
		return
	var preview := action_system.query_action({"action": &"attack", "unit": selected_unit, "target": target})
	if not bool(preview.get("valid", false)):
		hud.set_context_prompt("无法攻击 %s" % target.unit_name)
		return
	attack_preview_target = target
	attack_preview_data = preview.duplicate(true)
	var hit_percent := int(roundf(float(preview.get("hit_chance", 0.0)) * 100.0))
	var expected_damage := int(preview.get("damage", 0))
	hud.set_context_prompt(
		"再次点击确认攻击 %s：命中 %d%% · 预计伤害 %d · 目标 HP %d/%d · 右键取消" % [
			target.unit_name, hit_percent, expected_damage, target.current_hp, target.max_hp
		]
	)

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

	# CODE-CH1-010: 玩家移动通过统一动作契约提交
	var old_pos = selected_unit.grid_pos
	var preview = action_system.query_action({"action": &"move", "unit": selected_unit, "target": grid_pos})
	if not bool(preview.get("valid", false)):
		_log("移动失败：%s" % preview.get("reason", "unknown"))
		return
	var result = action_system.commit_action(preview)
	if not bool(result.get("success", false)):
		_log("移动失败：%s" % result.get("reason", "unknown"))
		return
	_update_unit_sprite_pos(selected_unit, true)
	AudioManager.sfx_move()

	# 检查警戒触发
	var triggers = action_system.check_overwatch_trigger(selected_unit, old_pos, grid_pos)
	for t in triggers:
		_log("%s 警戒射击 %s!" % [t.watcher.unit_name, t.target.unit_name])
		_update_unit_sprite_pos(t.target)

	# 移动会改变玩家视野，不能等到下一回合才更新战争迷雾。
	# 放在陷阱和警戒结算后，保证最终存活状态与最终位置都已写入。
	_update_visibility()

	_log("%s 移动到 (%d,%d)" % [selected_unit.unit_name, grid_pos.x, grid_pos.y])
	_clear_layer(path_preview_layer)
	path_preview.clear()
	selected_action = ""
	attack_preview_target = null
	attack_preview_data.clear()
	attack_confirmation_required = false
	hud.update_unit_info(selected_unit)
	_refresh_selected_unit_affordances(selected_unit)

	_check_encounter_zone(selected_unit.grid_pos)
	# CH1-090: Evac VFX when a unit steps onto an extraction cell.
	if selected_unit.grid_pos in evac_cells and mission_type in ["extract", "steal_data", "escort", "infiltrate"]:
		_spawn_effect("evac", selected_unit.grid_pos)
	_check_victory_instant()
	_advance_context_hint("move")

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

	var target_hp_before: int = int(target.current_hp)
	var attack_ok = _do_player_attack(selected_unit, target)
	attack_preview_target = null
	attack_preview_data.clear()
	# 刷新攻击范围显示
	if selected_unit and selected_unit.current_ap > 0:
		_show_attack_range(selected_unit)
	else:
		selected_action = ""
		_clear_layer(attack_highlight)
	hud.update_unit_info(selected_unit)
	if attack_ok:
		_advance_context_hint("attack")
		if attack_confirmation_required and selected_action == "attack":
			var result := last_player_attack_result
			var hit := bool(result.get("hit", false))
			var damage_dealt := maxi(0, target_hp_before - target.current_hp)
			if hit:
				hud.set_context_prompt("命中 %s：%d 伤害 · 目标 HP %d/%d · 点击其他红色目标预览" % [
					target.unit_name, damage_dealt, target.current_hp, target.max_hp
				])
			else:
				hud.set_context_prompt("攻击 %s：未命中 · 点击其他红色目标预览" % target.unit_name)

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
	_play_unit_state(attacker, &"attack", Vector2(target_pos - attacker.grid_pos))
	_spawn_effect("muzzle", attacker.grid_pos)
	_spawn_effect("destroy" if state.hp <= 0 else "hit", target_pos)
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
## CH1-040: 终端必须处于正在观察的格子才能交互
func _try_interact_terminal(unit: Unit, term_pos: Vector2i) -> bool:
	if not term_pos in terminals:
		return false
	if visibility_state and not visibility_state.is_cell_observed(term_pos):
		_log("终端未在观察范围内")
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
	_play_unit_state(unit, &"skill")
	_spawn_effect("terminal", term_pos)
	_log("%s 激活终端 (%d/%d)" % [unit.unit_name, terminals_activated, terminals_required])
	hud.update_objective(_get_objective_text())
	_check_victory_instant()
	_advance_context_hint("interact")
	return true

## CH1-080: 检测玩家单位是否进入新遭遇区，更新当前遭遇 ID。
func _check_encounter_zone(grid_pos: Vector2i) -> void:
	var encounters: Array = map_data.get("encounters", [])
	if encounters.is_empty():
		return
	for encounter in encounters:
		var trigger_cells: Array = encounter.get("trigger_cells", [])
		var eid: String = String(encounter.get("id", ""))
		if eid == "":
			continue
		for cell in trigger_cells:
			if typeof(cell) == TYPE_ARRAY and cell.size() == 2:
				var trigger_pos := Vector2i(int(cell[0]), int(cell[1]))
				if trigger_pos == grid_pos and current_encounter_id != eid:
					current_encounter_id = eid
					_log("进入遭遇区：%s" % String(encounter.get("name", eid)))
					return

## Task 3: calculate star rating (0=defeat, 1=victory, 2=no casualty, 3=fast+optional)
func _calculate_stars(
	victory: bool,
	survived: int,
	total: int,
	turns: int,
	optional_complete: bool
) -> int:
	if not victory:
		return 0
	if survived != total:
		return 1
	if turns > int(level_config.get("three_star_turns", 10)) or not optional_complete:
		return 2
	return 3

## Task 3: collect optional resource (player unit adjacent, costs 1 AP)
func _try_interact_resource(unit: Unit, resource_pos: Vector2i) -> bool:
	if not resource_pos in resource_positions:
		return false
	# CH1-040: 资源必须处于正在观察的格子才能交互
	if visibility_state and not visibility_state.is_cell_observed(resource_pos):
		_log("resource not in observed area")
		return false
	if not _is_adjacent_reachable(unit, resource_pos) and unit.grid_pos != resource_pos:
		_log("resource out of reach")
		return false
	if not unit.can_act():
		_log("cannot act")
		return false
	if not unit.spend_ap(1):
		_log("not enough AP")
		return false
	var result = mission_objective_state.apply_event(&"resource_interacted", {"unit": unit, "position": resource_pos})
	if not result.get("success", false):
		_log("resource collect failed: %s" % result.get("reason", "unknown"))
		return false
	_play_unit_state(unit, &"skill")
	_spawn_effect("heal", resource_pos)
	_log("%s collected optional resource (+%d credit)" % [unit.unit_name, int(result.get("credit_bonus", 0))])
	hud.update_objective(_get_objective_text())
	return true

## CODE-CH1-010: 玩家攻击通过统一动作契约提交（query→commit）
## 敌人 AI 和警戒射击触发仍使用 _do_attack 的直接 execute_attack 路径
func _do_player_attack(attacker: Unit, target: Unit) -> bool:
	last_player_attack_result.clear()
	var preview = action_system.query_action({"action": &"attack", "unit": attacker, "target": target})
	if not bool(preview.get("valid", false)):
		_log("攻击失败：%s" % preview.get("reason", "unknown"))
		return false
	var result = action_system.commit_action(preview)
	if result.get("success", false):
		last_player_attack_result = result.get("result", {}).duplicate(true)
		AudioManager.sfx_attack(AudioManager.get_weapon_sfx_profile(attacker.weapon_special))
		_play_unit_state(attacker, &"attack", Vector2(target.grid_pos - attacker.grid_pos))
		_spawn_effect("muzzle", attacker.grid_pos)
		var r = result.get("result", {})
		var hit = r.get("hit", false)
		var damage = int(r.get("damage", 0))
		var critical = r.get("critical", false)
		if hit:
			_spawn_effect("crit" if critical else "hit", target.grid_pos)
			if critical:
				AudioManager.sfx_critical()
				camera.play_event_feedback(&"critical", _get_cell_center(target.grid_pos))
			else:
				AudioManager.sfx_hit()
			if r.get("dodged", false):
				_log("%s 攻击 %s - 闪避!" % [attacker.unit_name, target.unit_name])
			elif critical:
				_log("%s 暴击 %s - %d伤害!" % [attacker.unit_name, target.unit_name, damage])
			else:
				_log("%s 命中 %s - %d伤害" % [attacker.unit_name, target.unit_name, damage])
		else:
			_spawn_effect("miss", target.grid_pos)
			_log("%s 攻击 %s - 未命中" % [attacker.unit_name, target.unit_name])
		# 记录遥测：闪避算作命中（攻击命中判定通过，但被闪避）
		_record_attack_telemetry(attacker, target, hit, damage, critical)
		_update_unit_sprite_pos(target)
		return true
	else:
		_log("攻击失败: %s" % result.get("reason", "unknown"))
		return false

func _do_attack(attacker: Unit, target: Unit) -> void:
	var result = action_system.execute_attack(attacker, target)
	if result.get("success", false):
		AudioManager.sfx_attack(AudioManager.get_weapon_sfx_profile(attacker.weapon_special))
		_play_unit_state(attacker, &"attack", Vector2(target.grid_pos - attacker.grid_pos))
		_spawn_effect("muzzle", attacker.grid_pos)
		var r = result.get("result", {})
		var hit = r.get("hit", false)
		var damage = int(r.get("damage", 0))
		var critical = r.get("critical", false)
		if hit:
			_spawn_effect("crit" if critical else "hit", target.grid_pos)
			if critical:
				AudioManager.sfx_critical()
				camera.play_event_feedback(&"critical", _get_cell_center(target.grid_pos))
			else:
				AudioManager.sfx_hit()
			if r.get("dodged", false):
				_log("%s 攻击 %s - 闪避!" % [attacker.unit_name, target.unit_name])
			elif critical:
				_log("%s 暴击 %s - %d伤害!" % [attacker.unit_name, target.unit_name, damage])
			else:
				_log("%s 命中 %s - %d伤害" % [attacker.unit_name, target.unit_name, damage])
		else:
			_spawn_effect("miss", target.grid_pos)
			_log("%s 攻击 %s - 未命中" % [attacker.unit_name, target.unit_name])
		# 记录遥测：闪避算作命中（攻击命中判定通过，但被闪避）
		_record_attack_telemetry(attacker, target, hit, damage, critical)
		_update_unit_sprite_pos(target)
	else:
		_log("攻击失败: %s" % result.get("reason", "unknown"))

func _end_player_turn() -> void:
	_deselect_unit()
	# CH1-050: Plan next enemy turn before handing control to the enemy phase.
	# The player can read the public intents during the enemy turn and act on
	# them next turn; the renderer and HUD are refreshed after planning.
	_plan_enemy_intents()
	_refresh_enemy_intent_display()
	turn_manager.end_player_turn()


## CH1-050: Generate next-turn intents for every alive enemy.
## Each intent captures the action the enemy would take if the player ended
## the turn right now. The plan is committed during the enemy action phase
## via _execute_enemy_action, so the public preview matches execution unless
## the player changes the board state (move/kill/disable) before ending turn.
func _plan_enemy_intents() -> void:
	if not enemy_planner or not enemy_intent_state:
		return
	enemy_intent_state.clear()
	for enemy in enemy_units:
		if not enemy or not enemy.is_alive:
			continue
		# Skip passive enemies (e.g. mission rules or tutorial first turn).
		if enemy.current_ap <= 0:
			continue
		var plan: Dictionary = enemy_planner.plan_action(
			enemy, player_units, enemy_units, visibility_state
		)
		var intent: Dictionary = plan.get("intent", {})
		if intent.is_empty():
			intent = {"type": "wait"}
		enemy_intent_state.set_intent(enemy.entity_id, intent)
	_enemy_intents_planned = true


## CH1-050: Refresh the intent renderer and HUD threat summary after a plan
## change or visibility update. Safe to call when no plan exists yet.
func _refresh_enemy_intent_display() -> void:
	if not enemy_intent_renderer or not enemy_intent_state:
		return
	# Sync enemy positions so the renderer can draw arrows from the right cell
	# even for stale intents where only the last-known snapshot is available.
	var positions: Dictionary = {}
	for enemy in enemy_units:
		if not enemy or not enemy.is_alive:
			continue
		positions[enemy.entity_id] = enemy.grid_pos
	enemy_intent_renderer.set_enemy_positions(positions)
	enemy_intent_renderer.refresh()
	if hud:
		hud.update_threat_summary(enemy_intent_state.get_threat_summary())

## Tab switches to the next player unit that still has AP.
func _on_next_unit() -> void:
	if turn_manager.current_phase != TurnManager.TurnPhase.PLAYER_ACTION or player_units.is_empty():
		return
	var alive_units = player_units.filter(func(u): return u != null and u.is_alive and u.current_ap > 0)
	if alive_units.is_empty():
		alive_units = player_units.filter(func(u): return u != null and u.is_alive)
	if alive_units.is_empty():
		return
	if selected_unit == null or not selected_unit in alive_units:
		_select_unit(alive_units[0])
	else:
		var idx = alive_units.find(selected_unit)
		var next_idx = (idx + 1) % alive_units.size()
		_select_unit(alive_units[next_idx])

## ===== HUD 按钮回调 =====

func on_move_button() -> void:
	if selected_unit and selected_unit.team == "player":
		selected_action = "move"
		hud.set_context_state(HUD.ContextState.MOVE_PREVIEW)
		_clear_layer(attack_highlight)
		_show_move_range(selected_unit)

func on_attack_button() -> void:
	if selected_unit and selected_unit.team == "player" and selected_unit.current_ap > 0:
		selected_action = "attack"
		attack_preview_target = null
		attack_preview_data.clear()
		attack_confirmation_required = false
		hud.set_context_state(HUD.ContextState.ATTACK_PREVIEW)
		_clear_layer(move_highlight)
		_clear_layer(path_preview_layer)
		path_preview.clear()
		reachable_cells.clear()
		_show_attack_range(selected_unit)

func on_skill_button() -> void:
	if not selected_unit or selected_unit.team != "player" or selected_unit.current_ap <= 0:
		return
	# 取消任何正在进行的行动选择/目标选择
	_cancel_targeting_if_active()
	hud.hide_action_picker()
	# 配置驱动：使用单位已学技能列表
	var skills = selected_unit.learned_skills
	if skills.is_empty():
		# 回退：该职业所有可学技能的第一个
		var job_skills = GameData.get_job_skills(selected_unit.job)
		if job_skills.is_empty():
			_log("%s 没有可用技能" % selected_unit.unit_name)
			return
		skills = [job_skills[0].id]
	# 构建技能选择面板项
	var items: Array = []
	for skill_id in skills:
		var skill_data = GameData.get_skill(skill_id)
		if skill_data.is_empty():
			continue
		# 跳过被动技能（type == "passive"）
		if String(skill_data.get("type", "active")) == "passive":
			continue
		var skill_name = String(skill_data.get("name", skill_id))
		var ap_cost = int(skill_data.get("ap_cost", 1))
		var cooldown = int(skill_data.get("cooldown", 0))
		var desc = String(skill_data.get("description", ""))
		var disabled = false
		var disabled_reason = ""
		if ap_cost > selected_unit.current_ap:
			disabled = true
			disabled_reason = "AP 不足（需要 %d）" % ap_cost
		if cooldown > 0 and int(skill_data.get("cooldown_remaining", 0)) > 0:
			disabled = true
			disabled_reason = "冷却中（剩余 %d 回合）" % int(skill_data.get("cooldown_remaining", 0))
		items.append({
			"id": skill_id,
			"name": "%s (%dAP)" % [skill_name, ap_cost],
			"description": desc,
			"disabled": disabled,
			"disabled_reason": disabled_reason,
		})
	if items.is_empty():
		_log("%s 没有可用主动技能" % selected_unit.unit_name)
		return
	hud.show_action_picker("选择技能", items, Callable(self, "_on_skill_selected"))

## 技能选择面板回调：选中技能后启动目标选择
func _on_skill_selected(skill_id: String) -> void:
	if not selected_unit or not selected_unit.is_alive:
		return
	var skill_data = GameData.get_skill(skill_id)
	if skill_data.is_empty():
		_log("技能数据缺失：%s" % skill_id)
		return
	_pending_action_id = skill_id
	_pending_action_kind = "skill"
	# 推断目标选择规格
	var spec = TargetingController.infer_skill_spec(skill_id, skill_data, selected_unit)
	# 如果目标是自身，直接执行，无需进入目标选择模式
	if spec.get("target_type") == TargetingController.TARGET_SELF:
		_execute_pending_action({"position": selected_unit.grid_pos, "target_unit": selected_unit})
		return
	# 进入目标选择模式
	_begin_targeting(spec)

func on_item_button() -> void:
	if not selected_unit or selected_unit.team != "player":
		return
	# 特殊规则：no_items 禁用物品使用
	if mission_objective_state and not mission_objective_state.is_item_use_allowed():
		var reason = mission_objective_state.get_rule_reason(MissionObjectiveState.RULE_NO_ITEMS)
		_log("物品被禁用：%s" % reason)
		mission_objective_state.special_rule_violated.emit(MissionObjectiveState.RULE_NO_ITEMS, reason)
		return
	_cancel_targeting_if_active()
	hud.hide_action_picker()
	# 配置驱动：使用单位可用物品列表
	var items_ids = selected_unit.available_items
	if items_ids.is_empty():
		items_ids = ["med_kit"]  # 回退
	# 构建物品选择面板项
	var items: Array = []
	for item_id in items_ids:
		var item_data = GameData.get_item(item_id)
		if item_data.is_empty():
			continue
		var item_name = String(item_data.get("name", item_id))
		var ap_cost = int(item_data.get("ap_cost", 1))
		var desc = String(item_data.get("description", ""))
		var disabled = false
		var disabled_reason = ""
		if ap_cost > selected_unit.current_ap:
			disabled = true
			disabled_reason = "AP 不足（需要 %d）" % ap_cost
		items.append({
			"id": item_id,
			"name": "%s (%dAP)" % [item_name, ap_cost],
			"description": desc,
			"disabled": disabled,
			"disabled_reason": disabled_reason,
		})
	if items.is_empty():
		_log("%s 没有可用物品" % selected_unit.unit_name)
		return
	hud.show_action_picker("选择物品", items, Callable(self, "_on_item_selected"))

## 物品选择面板回调：选中物品后启动目标选择
func _on_item_selected(item_id: String) -> void:
	if not selected_unit or not selected_unit.is_alive:
		return
	var item_data = GameData.get_item(item_id)
	if item_data.is_empty():
		_log("物品数据缺失：%s" % item_id)
		return
	_pending_action_id = item_id
	_pending_action_kind = "item"
	# 推断目标选择规格
	var spec = TargetingController.infer_item_spec(item_id, item_data, selected_unit)
	# 如果目标是自身，直接执行
	if spec.get("target_type") == TargetingController.TARGET_SELF:
		_execute_pending_action({"position": selected_unit.grid_pos, "target_unit": selected_unit})
		return
	# 进入目标选择模式
	_begin_targeting(spec)

## 启动目标选择模式
func _begin_targeting(spec: Dictionary) -> void:
	if not selected_unit or targeting_controller == null:
		return
	# 清除移动/攻击高亮，进入目标选择专属状态
	_clear_layer(move_highlight)
	_clear_layer(attack_highlight)
	_clear_layer(path_preview_layer)
	path_preview.clear()
	reachable_cells.clear()
	attack_targets.clear()
	selected_action = "targeting"
	# 构建上下文
	# CH1-040: 注入 visibility_state，使目标选择跳过未观察的敌人
	var context := {
		"map_width": map_width,
		"map_height": map_height,
		"players": player_units,
		"enemies": enemy_units,
		"los_check": Callable(self, "_has_los_for_targeting"),
		"action_system": action_system,
		"visibility_state": visibility_state,
	}
	targeting_controller.begin(selected_unit, _pending_action_id, spec, context)

## 视线检查适配器（供 TargetingController 使用）
func _has_los_for_targeting(from: Vector2i, to: Vector2i) -> bool:
	return VisionSystem.has_line_of_sight(
		from, to,
		map_width, map_height, _is_vision_blocking
	)

## 目标选择开始回调：高亮合法目标格
func _on_targeting_started(spec: Dictionary) -> void:
	_clear_layer(attack_highlight)
	var valid_cells = targeting_controller.get_valid_cells()
	var target_type = String(spec.get("target_type", ""))
	var color = _highlight_color("attack", COLOR_ATTACK)
	match target_type:
		TargetingController.TARGET_ALLY:
			color = _highlight_color("ally", Color(0.13, 0.59, 0.95, 0.35))
		TargetingController.TARGET_ENEMY:
			color = _highlight_color("attack", COLOR_ATTACK)
		TargetingController.TARGET_POSITION:
			color = _highlight_color("target", COLOR_TARGET)
		TargetingController.TARGET_ANY_UNIT:
			color = _highlight_color("target", COLOR_TARGET)
		_:
			color = _highlight_color("selected", COLOR_SELECTED)
	for cell in valid_cells:
		_highlight_cell(attack_highlight, cell, color)
	# 显示提示
	var hint_text = _get_targeting_hint_text(spec)
	hud.set_targeting_hint(hint_text)
	hud.update_objective(hint_text)

## 生成目标选择提示文本
func _get_targeting_hint_text(spec: Dictionary) -> String:
	var target_type = String(spec.get("target_type", ""))
	var range = int(spec.get("range", 0))
	var action_label = "技能" if _pending_action_kind == "skill" else "物品"
	var action_data = GameData.get_skill(_pending_action_id) if _pending_action_kind == "skill" else GameData.get_item(_pending_action_id)
	var action_name = String(action_data.get("name", _pending_action_id))
	match target_type:
		TargetingController.TARGET_ALLY:
			return "选择友方目标 (%s, 范围%d) - 右键取消" % [action_name, range]
		TargetingController.TARGET_ENEMY:
			return "选择敌方目标 (%s, 范围%d) - 右键取消" % [action_name, range]
		TargetingController.TARGET_POSITION:
			return "选择目标位置 (%s, 范围%d) - 右键取消" % [action_name, range]
		TargetingController.TARGET_ANY_UNIT:
			return "选择目标单位 (%s, 范围%d) - 右键取消" % [action_name, range]
		_:
			return "选择目标 - 右键取消"

## 目标确认回调：执行技能/物品
func _on_target_confirmed(target_data: Dictionary) -> void:
	_clear_layer(attack_highlight)
	hud.set_targeting_hint("")
	hud.update_objective(_get_objective_text())
	_execute_pending_action(target_data)

## 目标取消回调：恢复移动范围显示
func _on_targeting_cancelled() -> void:
	_clear_layer(attack_highlight)
	hud.set_targeting_hint("")
	hud.update_objective(_get_objective_text())
	_pending_action_id = ""
	_pending_action_kind = ""
	if selected_unit:
		selected_action = ""
		hud.update_unit_info(selected_unit)
		_refresh_selected_unit_affordances(selected_unit)
	else:
		selected_action = ""

## 取消正在进行的目标选择
func _cancel_targeting_if_active() -> void:
	if targeting_controller and targeting_controller.is_active:
		targeting_controller.cancel()

## 执行待定的技能/物品行动
func _execute_pending_action(target_data: Dictionary) -> void:
	if not selected_unit or not selected_unit.is_alive:
		_pending_action_id = ""
		_pending_action_kind = ""
		return
	var action_id = _pending_action_id
	var action_kind = _pending_action_kind
	# 清理待定状态
	_pending_action_id = ""
	_pending_action_kind = ""
	selected_action = ""
	var result: Dictionary
	var action_name = action_id
	if action_kind == "skill":
		var skill_data = GameData.get_skill(action_id)
		action_name = String(skill_data.get("name", action_id))
		# CODE-CH1-010: 技能通过统一动作契约提交
		var preview = action_system.query_action({"action": &"skill", "unit": selected_unit, "action_id": action_id})
		if not bool(preview.get("valid", false)):
			_log("%s 技能 %s 失败：%s" % [selected_unit.unit_name, action_name, preview.get("reason", "")])
		else:
			preview["target_data"] = target_data
			result = action_system.commit_action(preview)
			if result.get("success", false):
				AudioManager.sfx_skill()
				_play_unit_state(selected_unit, &"skill")
				_spawn_effect("heal" if action_id.contains("heal") else "terminal", selected_unit.grid_pos)
				_log("%s 使用技能：%s" % [selected_unit.unit_name, action_name])
				_record_skill_telemetry()
			else:
				_log("%s 技能 %s 失败：%s" % [selected_unit.unit_name, action_name, result.get("reason", "")])
	elif action_kind == "item":
		var item_data = GameData.get_item(action_id)
		action_name = String(item_data.get("name", action_id))
		var target_unit = target_data.get("target_unit", selected_unit)
		# CODE-CH1-010: 物品通过统一动作契约提交
		var preview = action_system.query_action({"action": &"item", "unit": selected_unit, "action_id": action_id})
		if not bool(preview.get("valid", false)):
			_log("%s 物品 %s 失败：%s" % [selected_unit.unit_name, action_name, preview.get("reason", "")])
		else:
			preview["target_data"] = target_data
			preview["target_unit"] = target_unit
			result = action_system.commit_action(preview)
			if result.get("success", false):
				AudioManager.sfx_heal()
				_spawn_effect("heal", selected_unit.grid_pos)
				_log("%s 使用物品：%s" % [selected_unit.unit_name, action_name])
				_record_item_telemetry()
			else:
				_log("%s 物品 %s 失败：%s" % [selected_unit.unit_name, action_name, result.get("reason", "")])
	# 刷新单位信息和移动范围
	hud.update_unit_info(selected_unit)
	_refresh_selected_unit_affordances(selected_unit)
	_check_victory_instant()

func on_overwatch_button() -> void:
	if selected_unit and selected_unit.team == "player" and selected_unit.current_ap > 0:
		# 特殊规则：no_overwatch 禁用警戒
		if mission_objective_state and not mission_objective_state.is_overwatch_allowed():
			var reason = mission_objective_state.get_rule_reason(MissionObjectiveState.RULE_NO_OVERWATCH)
			_log("警戒被禁用：%s" % reason)
			mission_objective_state.special_rule_violated.emit(MissionObjectiveState.RULE_NO_OVERWATCH, reason)
			return
		# CODE-CH1-010: 警戒通过统一动作契约提交
		var preview = action_system.query_action({"action": &"overwatch", "unit": selected_unit})
		if not bool(preview.get("valid", false)):
			_log("警戒失败：%s" % preview.get("reason", "unknown"))
			return
		var result = action_system.commit_action(preview)
		if bool(result.get("success", false)):
			AudioManager.sfx_overwatch()
			_log("%s 进入警戒" % selected_unit.unit_name)
			_record_overwatch_telemetry()
			hud.update_unit_info(selected_unit)
			_refresh_selected_unit_affordances(selected_unit)

func on_end_turn_button() -> void:
	_end_player_turn()

## ===== 单位事件回调 =====

func _on_unit_ap_changed(unit: Unit, _ap: int) -> void:
	if selected_unit == unit:
		hud.update_unit_info(unit)

func _on_unit_died(unit: Unit) -> void:
	_log("%s 阵亡" % unit.unit_name)
	AudioManager.sfx_unit_down()
	var sprite := _get_unit_sprite(unit)
	if sprite:
		sprite.update_unit(unit)
		sprite.play_death()
	_record_death_telemetry(unit)
	# Boss 死亡时更新目标显示
	if unit == boss_unit:
		_log("Boss 已被击杀！")
		hud.update_objective(_get_objective_text())

func _on_unit_damaged(unit: Unit, _amount: int) -> void:
	_update_unit_sprite_pos(unit)
	if unit.is_alive:
		_play_unit_state(unit, &"hit")
	# Boss 受伤时检查阶段切换
	if unit == boss_unit and boss_unit and boss_unit.is_alive:
		_check_boss_phase_transition(unit)

func _spawn_effect(kind: String, grid_pos: Vector2i) -> void:
	var effect := TacticalEffect.new()
	effect.position = _get_cell_center(grid_pos)
	effect.setup(kind)
	effect_layer.add_child(effect)
	if kind == "explosion":
		camera.play_event_feedback(&"explosion", effect.position)

func _check_victory_instant() -> void:
	if _check_victory():
		turn_manager._end_battle(true)

## ===== 辅助函数 =====

func _get_unit_at(pos: Vector2i) -> Unit:
	for unit in player_units + enemy_units:
		if unit and unit.is_alive and unit.grid_pos == pos:
			return unit
	return null

func _update_unit_sprite_pos(unit: Unit, animate: bool = false) -> void:
	var sprite := _get_unit_sprite(unit)
	if not sprite:
		return
	sprite.update_unit(unit)
	var target_position := _get_cell_center(unit.grid_pos)
	if animate:
		sprite.play_move_to(target_position)
	else:
		sprite.position = target_position

func _play_unit_state(unit: Unit, state: StringName, direction: Vector2 = Vector2.RIGHT) -> void:
	var sprite := _get_unit_sprite(unit)
	if sprite:
		sprite.play_state(state, direction)

func _get_unit_sprite(unit: Unit) -> UnitSprite:
	for sprite in unit_layer.get_children():
		if sprite is UnitSprite and sprite.unit == unit:
			return sprite
	return null

func _get_cell_center(pos: Vector2i) -> Vector2:
	return GridSystem.grid_to_world(pos) + Vector2(CELL_SIZE, CELL_SIZE) * 0.5

func _update_unit_sprite_selection(unit: Unit, selected: bool) -> void:
	for sprite in unit_layer.get_children():
		if sprite is UnitSprite and sprite.unit == unit:
			sprite.set_selected(selected)
			return

func _get_move_cost(pos: Vector2i, job: String) -> int:
	return GameData.get_move_cost(job, MapLoader.get_terrain_at(map_data, pos.x, pos.y))

## CODE-P2-01: Update visibility from all alive player units.
## Computes visible cells, updates VisibilityState, and refreshes enemy sprite visibility.
## CH1-040: 同步回合戳、刷新迷雾渲染层、渲染最后已知位置幽灵。
func _update_visibility() -> void:
	if not visibility_state:
		return
	visibility_state.set_turn(turn_manager.turn_number if turn_manager else 1)
	var visible_cells: Array[Vector2i] = []
	for unit in player_units:
		if not unit or not unit.is_alive:
			continue
		var cells = VisionSystem.get_visible_cells(
			unit.grid_pos, unit.vision_range,
			map_width, map_height,
			_is_vision_blocking
		)
		for cell in cells:
			if not visible_cells.has(cell):
				visible_cells.append(cell)
	# Collect visible enemy data
	var visible_enemies: Array = []
	for enemy in enemy_units:
		if not enemy or not enemy.is_alive:
			continue
		if visible_cells.has(enemy.grid_pos):
			visible_enemies.append({
				"entity_id": enemy.entity_id,
				"pos": enemy.grid_pos,
				"hp": enemy.current_hp,
			})
	visibility_state.update_visibility(visible_cells, visible_enemies)
	_refresh_enemy_sprite_visibility()
	_refresh_last_known_ghosts()
	if visibility_renderer:
		visibility_renderer.set_camera_cells(_camera_zone_cells)
		visibility_renderer.refresh()
	if hud and hud.is_network_overlay_visible():
		_update_network_node_visibility()
	# CH1-050: Visibility changes affect which intents are public. Refresh the
	# intent renderer so newly observed/lost enemies update their display.
	_refresh_enemy_intent_display()

## CODE-P2-01: Hide enemy sprites not currently observed; show observed ones.
## CH1-040: 实时敌人精灵只在正在观察时显示；离开视野后隐藏，由幽灵标记取代。
func _refresh_enemy_sprite_visibility() -> void:
	for child in unit_layer.get_children():
		if not child is UnitSprite:
			continue
		var sprite = child as UnitSprite
		if not sprite or not sprite.unit:
			continue
		if sprite.unit.team != "enemy":
			continue
		var observed = visibility_state.is_enemy_observed(sprite.unit.entity_id)
		sprite.visible = observed

## CH1-040: 渲染最后已知位置幽灵标记。
## 离开视野的敌人在其最后已知格（已记录或正在观察）显示一个半透明轮廓 + "?" 不确定标记，
## 不显示实时生命、意图或朝向。未探索区域的最后已知位置不渲染（玩家从未到过那里）。
func _refresh_last_known_ghosts() -> void:
	# 清理旧幽灵
	for ghost in _last_known_ghosts.values():
		if ghost and is_instance_valid(ghost):
			ghost.queue_free()
	_last_known_ghosts.clear()
	if not visibility_state:
		return
	var renderable: Dictionary = visibility_state.get_renderable_last_known()
	for eid in renderable.keys():
		# 若敌人当前正在观察，则实时精灵已显示，不需要幽灵
		if visibility_state.is_enemy_observed(eid):
			continue
		var snapshot: Dictionary = renderable[eid]
		var pos = snapshot.get("pos", null)
		if pos == null or not (pos is Vector2i):
			continue
		var ghost := UnitSprite.new()
		ghost.name = "Ghost_%s" % eid
		ghost.modulate = Color(1.0, 1.0, 1.0, 0.42)
		ghost.z_index = 90
		ghost.is_ghost = true
		ghost.ghost_uncertain = bool(snapshot.get("uncertain", true))
		unit_layer.add_child(ghost)
		# 幽灵使用一个临时的 Unit 引用以便 _draw 工作；不连接信号以避免副作用
		var placeholder := Unit.new()
		placeholder.team = "enemy"
		placeholder.unit_name = String(snapshot.get("name", eid))
		placeholder.job = String(snapshot.get("job", "sentry"))
		placeholder.entity_id = eid
		placeholder.grid_pos = pos
		placeholder.is_alive = true
		placeholder.current_hp = int(snapshot.get("hp", 1))
		placeholder.max_hp = max(1, placeholder.current_hp)
		placeholder.max_ap = 0
		placeholder.current_ap = 0
		placeholder.max_shield = 0
		placeholder.current_shield = 0
		ghost.update_unit(placeholder)
		ghost.position = _get_cell_center(pos)
		ghost.set_meta("ghost_entity_id", eid)
		ghost.set_meta("ghost_uncertain", bool(snapshot.get("uncertain", true)))
		ghost.set_meta("ghost_turn_seen", int(snapshot.get("turn_seen", -1)))
		_last_known_ghosts[eid] = ghost

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
