## 战斗 HUD 契约测试
## 验证选中玩家单位时显示五个行动按钮，选中敌人时不显示
## 验证按钮图标尺寸受限，不挤压 HUD
extends Node

const BattleScene = preload("res://scenes/battle.tscn")
const GameDataScript = preload("res://scripts/data/game_data.gd")
const TutorialHintScript = preload("res://scripts/ui/tutorial_hint.gd")
const HUDScript = preload("res://scripts/ui/hud.gd")
const DialogueSystemScript = preload("res://scripts/ui/dialogue_system.gd")

var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []
var _battle: Node = null

func _ready() -> void:
	print("=== 战斗 HUD 契约测试 ===")
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	await get_tree().process_frame

	GameManager.begin_new_game_for_test(0)
	GameManager.current_level_id = "ch1_m1"
	await _test_hud_contract()
	await _test_cooling_works_render_contract()
	await _test_mission_event_reinforcement_bridge()
	await _test_viewport_fills_at_22x16()
	await _test_input_actions()
	await _test_network_toggle_and_alert_display()
	await _test_player_move_uses_commit_action()
	await get_tree().process_frame

	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	# queue_free() is deferred; give both scene-tree queues a frame before exit so
	# rendering resources from the two instantiated battle scenes are released.
	await get_tree().process_frame
	await get_tree().physics_frame
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", message)
	else:
		_failed += 1
		_errors.append(message)
		print("  [FAIL] ", message)

func _test_hud_contract() -> void:
	print("\n--- 测试: HUD 按钮可见性与图标尺寸 ---")
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_battle.get_script() != null, "战斗控制脚本成功加载")
	if _battle.get_script() == null:
		return

	var hud = _battle.get_node_or_null("HUD")
	_check(hud != null, "HUD 节点存在")
	if hud == null:
		return

	# 战斗地图必须使用可约束的专用相机，并在首帧完成地图/HUD 布局。
	var camera = _battle.get_node_or_null("Camera2D")
	_check(camera is BattleCameraController, "战斗场景使用 BattleCameraController")
	if camera is BattleCameraController:
		var expected_bounds_size = Vector2(_battle.map_width * _battle.CELL_SIZE, _battle.map_height * _battle.CELL_SIZE) + Vector2(80, 80)
		_check(camera._map_bounds.size == expected_bounds_size, "相机边界包含地图和单位视觉安全边")
		_check(camera._safe_viewport.size.x < get_viewport().get_visible_rect().size.x, "相机安全区为右侧单位面板预留空间")
		_check(camera._safe_viewport.position.y >= HUDScript.TOP_BAR_HEIGHT, "相机安全区避开顶部 HUD")
		# Task 5: readable camera opens at 1.0 zoom on the deployment
		_check(is_equal_approx(camera.zoom.x, 1.0), "large map starts at readable 1.0 zoom")
		var deployment_center: Vector2 = _battle.get_player_deployment_center()
		_check(camera.position.distance_to(deployment_center + camera._get_safe_viewport_offset()) < 2.0,
			"camera opens on the three-unit deployment")
		# drag pans the battlefield
		var before_drag: Vector2 = camera.position
		camera.begin_drag(Vector2(500, 350))
		camera.drag_to(Vector2(420, 300))
		camera.end_drag()
		_check(camera.position.distance_to(before_drag) > 1.0, "middle-drag pans the battlefield")
		# overview fits more of the map, second toggle restores
		var readable_zoom: Vector2 = camera.zoom
		camera.toggle_overview()
		_check(camera.zoom.x < readable_zoom.x, "toggle_overview action fits more of the map")
		camera.toggle_overview()
		_check(camera.zoom.is_equal_approx(readable_zoom), "second toggle_overview restores readable zoom")
		# all four map corners are reachable
		for corner in [
			camera._map_bounds.position,
			camera._map_bounds.position + Vector2(camera._map_bounds.size.x, 0),
			camera._map_bounds.position + Vector2(0, camera._map_bounds.size.y),
			camera._map_bounds.end,
		]:
			camera.focus_home(corner)
			var safe_world_center: Vector2 = camera.position - camera._get_safe_viewport_offset()
			var safe_world_size: Vector2 = camera._safe_viewport.size / camera.zoom
			var visible_world := Rect2(safe_world_center - safe_world_size * 0.5, safe_world_size)
			_check(visible_world.grow(1.0).has_point(corner), "camera can reach map corner %s" % corner)
	var action_bar = hud.get_node_or_null("BottomBar/ActionBar")
	_check(action_bar != null and action_bar.offset_right > 0.0, "HUD 在启动时应用视口布局")
	var shortcut_hint: Label = hud.get_node_or_null("BottomBar/ShortcutHint")
	_check(shortcut_hint != null and shortcut_hint.visible, "底部显示常用操作提示")
	_check(shortcut_hint != null and shortcut_hint.text.contains("右键移动/取消") and shortcut_hint.text.contains("G网络"), "操作提示包含移动/取消和网络快捷键")
	_check(shortcut_hint != null and shortcut_hint.text.contains("Home聚焦") and shortcut_hint.text.contains("Space结束"), "操作提示包含聚焦和结束回合快捷键")
	_check(shortcut_hint != null and shortcut_hint.get_global_rect().position.y >= get_viewport().get_visible_rect().size.y - 60.0, "操作提示位于底部栏内")
	var objective_label: Label = hud.get_node_or_null("TopBar/ObjectiveLabel")
	var viewport_width := get_viewport().get_visible_rect().size.x
	_check(objective_label != null and objective_label.size.x >= viewport_width * 0.5, "顶部目标栏使用可显示 Boss 状态的响应式宽度")
	var top_bar = hud.get_node_or_null("TopBar")
	var right_panel = hud.get_node_or_null("RightPanel")
	_check(top_bar != null and is_equal_approx(top_bar.offset_bottom, HUDScript.TOP_BAR_HEIGHT), "顶部栏为警报第二行保留空间")
	_check(right_panel != null and is_equal_approx(right_panel.offset_top, HUDScript.TOP_BAR_HEIGHT), "右侧单位面板避开扩展后的顶部栏")
	_check(right_panel != null and right_panel.get_global_rect().position.x >= viewport_width - 250.0, "右侧单位面板实际停靠在视口右侧")
	var threat_label: Label = hud.get_node_or_null("RightPanel/ThreatLabel")
	hud.update_threat_summary({
		"total": 1,
		"move_count": 1,
		"top_threats": [{"type": "move", "stale": false, "lethal": false}],
	})
	_check(threat_label != null and threat_label.visible, "敌方意图摘要在有情报时可见")
	_check(threat_label != null and threat_label.text.contains("已知敌方意图"), "敌方意图摘要使用明确中文标题")
	_check(threat_label != null and threat_label.get_global_rect().position.x >= viewport_width - 250.0, "敌方意图摘要实际位于右侧单位面板")
	hud.update_threat_summary({"total": 0})

	# 战斗对话必须与教程一样位于 CanvasLayer，否则会被战场相机缩放和裁切。
	var dialogue = GameManager._active_dialogue
	_check(dialogue != null and dialogue.get_parent() == hud, "战斗对话挂载在 HUD CanvasLayer")
	if dialogue:
		var dialogue_panel: Control = dialogue.get_node("Panel")
		var dialogue_rect := dialogue_panel.get_global_rect()
		var dialogue_center := get_viewport().get_visible_rect().size * 0.5
		_check(dialogue_rect.size.is_equal_approx(Vector2(800, 360)), "战斗对话保持 800x360 正式尺寸")
		_check(dialogue_rect.get_center().is_equal_approx(dialogue_center), "战斗对话在视口居中")
		dialogue.free()
		GameManager._active_dialogue = null

	# 教程必须位于不受战场相机缩放影响的 CanvasLayer，并保持正式弹窗尺寸。
	_battle._show_tutorial_flag("teach_movement")
	await get_tree().process_frame
	var tutorial = _battle._active_tutorial_hint
	_check(tutorial != null and tutorial.get_parent() == hud, "教程提示挂载在 HUD CanvasLayer")
	if tutorial:
		var tutorial_panel: Control = tutorial.get_node("Panel")
		var panel_rect := tutorial_panel.get_global_rect()
		var viewport_center := get_viewport().get_visible_rect().size * 0.5
		_check(panel_rect.size.is_equal_approx(Vector2(600, 280)), "教程提示保持 600x280 正式尺寸")
		_check(panel_rect.get_center().is_equal_approx(viewport_center), "教程提示在视口居中")
		tutorial.free()
		_battle._active_tutorial_hint = null
		_battle._pending_tutorial_flags.clear()
	_check(TutorialHintScript.get_hint_copy("teach_movement").contains("下方【移动】"), "移动教程说明动作栏与高亮目标格")
	_check(TutorialHintScript.get_hint_copy("teach_attack").contains("下方【攻击】"), "攻击教程说明动作栏与红色目标")

	# 正式地图必须渲染环境组件，而不是退回纯色程序格。
	var map_layer = _battle.get_node_or_null("MapLayer")
	var first_tile = map_layer.get_node_or_null("Tile_0_0") if map_layer else null
	_check(first_tile != null, "环境渲染为每个格子提供稳定节点名")
	if first_tile:
		_check(first_tile.get("environment_kit") == "echo_yard", "ch1_m1 格子使用 echo_yard 环境套件")
		_check(first_tile.get("floor_texture") is Texture2D, "环境格加载正式地板纹理")
	var blocker_tile = map_layer.get_node_or_null("Tile_4_3") if map_layer else null
	_check(blocker_tile != null and blocker_tile.get("blocker_texture") is Texture2D, "阻挡格加载独立货场道具纹理")
	var threshold_tile = map_layer.get_node_or_null("Tile_5_0") if map_layer else null
	var edge_variants = threshold_tile.get("edge_variants") if threshold_tile else null
	_check(edge_variants is Array and not edge_variants.is_empty(), "材质交界格加载邻接边缘叠层")
	_check(map_layer != null and map_layer.get_node_or_null("Environment_landmark_0") != null, "战场实例化龙门吊地标")
	_check(map_layer != null and map_layer.get_node_or_null("Environment_landmark_1") != null, "战场实例化照明塔地标")
	var decorations_fit_map := true
	if map_layer:
		var map_rect := Rect2(Vector2.ZERO, Vector2(_battle.map_width * _battle.CELL_SIZE, _battle.map_height * _battle.CELL_SIZE))
		for child in map_layer.get_children():
			if child is Sprite2D and String(child.name).begins_with("Environment_") and child.texture:
				var decoration_rect := Rect2(child.position, child.texture.get_size())
				if not map_rect.encloses(decoration_rect):
					decorations_fit_map = false
	_check(decorations_fit_map, "环境地标完整限制在地图视觉边界内")
	_check(_battle.visibility_renderer != null and _battle.visibility_renderer.z_index >= 2, "迷雾层覆盖环境装饰但低于单位层")

	# 单位必须使用正式纹理并居中落在格内，不能再显示程序化字母棋子或格点偏移。
	var unit_layer = _battle.get_node_or_null("UnitLayer")
	var first_player_view: UnitSprite = null
	if unit_layer:
		for child in unit_layer.get_children():
			if child is UnitSprite and child.unit.team == "player":
				first_player_view = child
				break
	_check(first_player_view != null, "战场实例化玩家单位视图")
	if first_player_view:
		var art = first_player_view.get_node_or_null("Art")
		_check(art is Sprite2D and art.texture is Texture2D, "玩家单位视图加载正式纹理")
		var expected_center = GridSystem.grid_to_world(first_player_view.unit.grid_pos) + Vector2(_battle.CELL_SIZE, _battle.CELL_SIZE) * 0.5
		_check(first_player_view.position.is_equal_approx(expected_center), "玩家单位位于战术格中心")
		_battle._select_unit(first_player_view.unit)
		var move_overlays = _battle.move_highlight.get_children()
		_check(not move_overlays.is_empty(), "选中单位会创建移动范围高亮")
		var overlays_ignore_mouse := true
		for overlay in move_overlays:
			if not overlay is Control or overlay.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				overlays_ignore_mouse = false
				break
		_check(overlays_ignore_mouse, "战术高亮不拦截玩家地图点击")
		_battle._deselect_unit()

	# 移动模式不能吞掉切换队员的点击，否则玩家移动一人后无法操作第二人。
	if _battle.player_units.size() >= 2:
		var first_player: Unit = _battle.player_units[0]
		var second_player: Unit = _battle.player_units[1]
		_battle._select_unit(first_player)
		_battle.on_move_button()
		var second_player_world = GridSystem.grid_to_world(second_player.grid_pos) + Vector2(_battle.CELL_SIZE, _battle.CELL_SIZE) * 0.5
		_battle._handle_left_click(second_player_world)
		_check(_battle.selected_unit == second_player, "移动模式下点击友军会切换当前操作单位")
		_check(_battle.selected_action == "", "切换友军会退出残留的移动模式")
		_battle._deselect_unit()

	# 多人撤离必须使用可见的区域，而不是要求单位重叠在同一个锚点格。
	var evac_zone_layer = _battle.get_node_or_null("EvacZoneLayer")
	_check(_battle.evac_cells.size() >= _battle.player_units.size(), "撤离区域可容纳本关全部玩家单位")
	_check(evac_zone_layer != null and evac_zone_layer.get_child_count() == _battle.evac_cells.size() - 1, "撤离区域为锚点外格子绘制常驻提示")
	var evac_overlays_ignore_mouse := true
	if evac_zone_layer:
		for overlay in evac_zone_layer.get_children():
			if not overlay is Control or overlay.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				evac_overlays_ignore_mouse = false
				break
	_check(evac_overlays_ignore_mouse, "撤离区域提示不拦截地图点击")
	_check(objective_label != null and objective_label.text.contains("终端"), "顶部目标明确要求当前阶段目标")

	# 地面效果不能只存在于规则数据中，必须在战场上生成并在到期后移除视觉节点。
	_battle.action_system._create_ground_effect(Vector2i(2, 2), 0, "smoke", 1)
	await get_tree().process_frame
	var effect_layer = _battle.get_node_or_null("EffectLayer")
	_check(effect_layer != null and effect_layer.get_node_or_null("GroundEffect_2_2_smoke") != null, "烟雾地面效果显示在战场上")
	_battle.action_system.process_ground_effects_on_turn_start()
	await get_tree().process_frame
	_check(effect_layer != null and effect_layer.get_node_or_null("GroundEffect_2_2_smoke") == null, "过期地面效果从战场移除")

	# 验证行动按钮节点存在
	var move_btn = hud.get_node_or_null("BottomBar/ActionBar/MoveButton")
	var attack_btn = hud.get_node_or_null("BottomBar/ActionBar/AttackButton")
	var skill_btn = hud.get_node_or_null("BottomBar/ActionBar/SkillButton")
	var item_btn = hud.get_node_or_null("BottomBar/ActionBar/ItemButton")
	var overwatch_btn = hud.get_node_or_null("BottomBar/ActionBar/OverwatchButton")
	var end_turn_btn = hud.get_node_or_null("BottomBar/ActionBar/EndTurnButton")

	_check(move_btn != null, "MoveButton 存在")
	_check(attack_btn != null, "AttackButton 存在")
	_check(skill_btn != null, "SkillButton 存在")
	_check(item_btn != null, "ItemButton 存在")
	_check(overwatch_btn != null, "OverwatchButton 存在")
	_check(end_turn_btn != null, "EndTurnButton 存在")

	if move_btn == null or end_turn_btn == null:
		return

	# 初始状态：行动按钮应隐藏，结束回合应可见
	_check(not move_btn.visible, "初始状态 MoveButton 隐藏")
	_check(not attack_btn.visible, "初始状态 AttackButton 隐藏")
	_check(end_turn_btn.visible, "初始状态 EndTurnButton 可见")

	# 创建玩家单位并选中
	var player_unit = GameData.create_player_unit("assault", "TestSoldier")
	_battle.selected_unit = player_unit
	hud.update_unit_info(player_unit)

	# 验证五个行动按钮可见
	_check(move_btn.visible, "选中玩家单位后 MoveButton 可见")
	_check(attack_btn.visible, "选中玩家单位后 AttackButton 可见")
	_check(skill_btn.visible, "选中玩家单位后 SkillButton 可见")
	_check(item_btn.visible, "选中玩家单位后 ItemButton 可见")
	_check(overwatch_btn.visible, "选中玩家单位后 OverwatchButton 可见")
	_check(end_turn_btn.visible, "选中玩家单位后 EndTurnButton 仍可见")

	# 验证单位信息标签有内容
	var unit_info_label = hud.get_node_or_null("RightPanel/UnitInfoLabel")
	if unit_info_label:
		_check(unit_info_label.text.length() > 0, "单位信息标签有内容")
		_check(unit_info_label.text.contains("TestSoldier"), "单位信息包含单位名称")

	# 创建敌人单位并选中
	var enemy_unit = GameData.create_enemy_unit("sentry_basic")
	_battle.selected_unit = enemy_unit
	hud.update_unit_info(enemy_unit)

	# 验证行动按钮隐藏（敌人不显示玩家行动按钮）
	_check(not move_btn.visible, "选中敌人后 MoveButton 隐藏")
	_check(not attack_btn.visible, "选中敌人后 AttackButton 隐藏")
	_check(not skill_btn.visible, "选中敌人后 SkillButton 隐藏")
	_check(not item_btn.visible, "选中敌人后 ItemButton 隐藏")
	_check(not overwatch_btn.visible, "选中敌人后 OverwatchButton 隐藏")
	_check(end_turn_btn.visible, "选中敌人后 EndTurnButton 仍可见")

	# 验证图标尺寸受限（通过 theme_override_constants）
	var icon_max = end_turn_btn.get_theme_constant("icon_max_width")
	_check(icon_max > 0 and icon_max <= 24, "EndTurnButton 图标尺寸受限 (当前: %d, 应 <= 24)" % icon_max)

	# 验证按钮尺寸不超过 120x48
	_check(end_turn_btn.custom_minimum_size.x <= 120, "EndTurnButton 宽度 <= 120 (当前: %d)" % int(end_turn_btn.custom_minimum_size.x))
	_check(end_turn_btn.custom_minimum_size.y <= 48, "EndTurnButton 高度 <= 48 (当前: %d)" % int(end_turn_btn.custom_minimum_size.y))

	# 清理
	if player_unit and is_instance_valid(player_unit):
		player_unit.free()
	if enemy_unit and is_instance_valid(enemy_unit):
		enemy_unit.free()
	await _dispose_battle()

func _test_cooling_works_render_contract() -> void:
	print("\n--- 测试: Cooling Works 正式地图渲染 ---")
	GameManager.current_level_id = "ch1_m2"
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(_battle.map_width == 16 and _battle.map_height == 12, "ch1_m2 在战斗场景加载为 16 x 12 地图")
	var map_layer = _battle.get_node_or_null("MapLayer")
	_check(map_layer != null and map_layer.get_child_count() >= 192, "Cooling Works 为所有战术格实例化渲染节点")
	var coolant_tile = map_layer.get_node_or_null("Tile_7_6") if map_layer else null
	_check(coolant_tile != null and coolant_tile.get("environment_kit") == "cooling_works", "冷却液区域使用 cooling_works 环境套件")
	_check(coolant_tile != null and coolant_tile.get("floor_variant") == 2 and coolant_tile.get("floor_texture") is Texture2D, "冷却液区域加载专属发光地板纹理")
	var basin_blocker = map_layer.get_node_or_null("Tile_7_6") if map_layer else null
	_check(basin_blocker != null and basin_blocker.get("blocker_texture") is Texture2D, "危险盆地的阻挡格加载专属环境道具")
	_check(map_layer != null and map_layer.get_node_or_null("Environment_landmark_0") != null, "战场实例化冷却塔地标")
	_check(map_layer != null and map_layer.get_node_or_null("Environment_landmark_1") != null, "战场实例化涡轮歧管地标")

	await _dispose_battle()

func _test_mission_event_reinforcement_bridge() -> void:
	print("\n--- 测试: 任务事件驱动增援生成 ---")
	GameManager.current_level_id = "ch1_m1"
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if _battle.get_script() == null:
		_check(false, "战斗脚本加载失败，跳过事件增援测试")
		await _dispose_battle()
		return

	var mos: MissionObjectiveState = _battle.mission_objective_state
	var connected := mos != null and mos.mission_event.is_connected(Callable(_battle, "_on_mission_event"))
	_check(connected, "BattleController 连接 mission_event 到 _on_mission_event")
	if not connected:
		await _dispose_battle()
		return

	# 注入事件触发型增援：终端激活 → 2 个敌人
	_battle.enemy_director.reinforcement_triggers.clear()
	_battle.enemy_director.reinforcement_triggers.append({
		"trigger_id": "test_terminal_wave",
		"trigger": {"type": "event", "name": "terminal_activated"},
		"action": "spawn_reinforcement",
		"data": {"units": [
			{"type": "sentry_basic", "position": [16, 12]},
			{"type": "sentry_basic", "position": [17, 11]},
		]},
		"repeat": false,
		"triggered": false,
	})
	_battle.enemy_director.max_reinforcements = 10
	_battle.enemy_director.enemy_cap_per_wave = 20
	var alive_p := 0
	var alive_e := 0
	for u in _battle.player_units:
		if u and u.is_alive:
			alive_p += 1
	for u in _battle.enemy_units:
		if u and u.is_alive:
			alive_e += 1
	_battle.enemy_director.set_alive_counts(alive_p, alive_e)

	var before = _battle.enemy_units.size()
	_battle.mission_objective_state.mission_event.emit(&"terminal_activated", {})
	await get_tree().process_frame
	var after = _battle.enemy_units.size()
	_check(after == before + 2, "terminal_activated 事件生成 2 个增援单位 (before=%d after=%d)" % [before, after])

	await _dispose_battle()
func _test_viewport_fills_at_22x16() -> void:
	print("\n--- 测试: 22x16 地图视口填充 ---")
	# 模拟 22x16 地图的边界
	var map_w := 22
	var map_h := 16
	var cell_size := 64.0
	var viewport_size := Vector2(1280, 720)
	var top_hud := 50.0
	var bottom_hud := 60.0
	var right_panel := 250.0
	var map_bounds := Rect2(
		Vector2.ONE * -40.0,
		Vector2(map_w * cell_size, map_h * cell_size) + Vector2.ONE * 80.0
	)
	var safe_viewport := Rect2(
		Vector2(0.0, top_hud),
		Vector2(maxf(1.0, viewport_size.x - right_panel), maxf(1.0, viewport_size.y - top_hud - bottom_hud))
	)
	# 创建临时相机测试
	var test_camera := BattleCameraController.new()
	add_child(test_camera)
	test_camera.configure_bounds(map_bounds, safe_viewport)
	# 断言：22x16 地图在 1.0 缩放时，安全视口高度不小于地图的可视部分
	var safe_height := safe_viewport.size.y
	var map_pixel_height := map_h * cell_size
	_check(test_camera.zoom.is_equal_approx(Vector2.ONE * 1.0), "22x16 默认 1.0 缩放")
	if map_pixel_height < safe_height:
		var visible_world_height := safe_height / test_camera.zoom.x
		_check(visible_world_height <= map_pixel_height + 80.0, "22x16 视口不产生下半空白区")
	for corner in [map_bounds.position, map_bounds.position + Vector2(map_bounds.size.x, 0), map_bounds.position + Vector2(0, map_bounds.size.y), map_bounds.end]:
		test_camera.focus_home(corner)
		var safe_world_center: Vector2 = test_camera.position - test_camera._get_safe_viewport_offset()
		var safe_world_size: Vector2 = test_camera._safe_viewport.size / test_camera.zoom
		var visible_world := Rect2(safe_world_center - safe_world_size * 0.5, safe_world_size)
		_check(visible_world.grow(1.0).has_point(corner), "22x16 角落可达: %s" % corner)
	test_camera.queue_free()
func _test_input_actions() -> void:
	print("\n--- 测试: 输入动作契约 ---")
	# Space 结束回合
	_check(InputMap.has_action("end_turn"), "end_turn 动作存在")
	_check(InputMap.has_action("next_unit"), "next_unit 动作存在")
	_check(InputMap.has_action("pause"), "pause 动作存在")
	_check(InputMap.has_action("toggle_overview"), "toggle_overview 动作存在")
	_check(InputMap.has_action("toggle_network"), "toggle_network 动作存在")
	# 对话名称本地化（直接检查类常量，避免实例化 CanvasLayer）
	_check(DialogueSystemScript.SPEAKER_NAMES.get("alpha", "") == "阿尔法", "alpha 映射为阿尔法")
	_check(DialogueSystemScript.SPEAKER_NAMES.get("commander", "") == "指挥官", "commander 映射为指挥官")
	_check(DialogueSystemScript.SPEAKER_NAMES.get("lila", "") == "莉拉", "lila 映射为莉拉")
	# HUD 上下文状态枚举
	_check(HUDScript.ContextState.NONE == 0, "ContextState.NONE 存在")
	_check(HUDScript.ContextState.UNIT_SELECTED == 1, "ContextState.UNIT_SELECTED 存在")
	_check(HUDScript.ContextState.MOVE_PREVIEW == 2, "ContextState.MOVE_PREVIEW 存在")
	_check(HUDScript.ContextState.ATTACK_PREVIEW == 3, "ContextState.ATTACK_PREVIEW 存在")
	_check(HUDScript.ContextState.FACILITY_PREVIEW == 4, "ContextState.FACILITY_PREVIEW 存在")


func _test_network_toggle_and_alert_display() -> void:
	print("\n--- 测试: G 键切换网络覆盖层与警报显示 ---")
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if _battle.get_script() == null:
		_check(false, "战斗脚本加载")
		_battle.queue_free()
		await get_tree().process_frame
		return

	var hud = _battle.get_node_or_null("HUD")
	_check(hud != null, "HUD 节点存在")
	if hud == null:
		await _dispose_battle()
		return

	# 验证警报标签和网络覆盖层节点存在
	_check(hud.get_node_or_null("TopBar/AlertLabel") != null, "HUD 创建 AlertLabel 节点")
	_check(hud.get_node_or_null("NetworkOverlay") != null, "HUD 创建 NetworkOverlay 节点")
	_check(not hud.is_network_overlay_visible(), "网络覆盖层初始隐藏")

	# 验证 G 键切换只影响可视化，不改变游戏状态
	var unit: Unit = _battle.player_units[0]
	var ap_before: int = unit.current_ap
	var hp_before: int = unit.current_hp
	var pos_before: Vector2i = unit.grid_pos

	# 第一次切换：显示
	_battle._on_toggle_network()
	_check(hud.is_network_overlay_visible(), "第一次 G 切换后网络覆盖层显示")
	_check(_battle.tactical_network_state.overlay_visible == true, "tactical_network_state.overlay_visible 为 true")

	# 第二次切换：隐藏
	_battle._on_toggle_network()
	_check(not hud.is_network_overlay_visible(), "第二次 G 切换后网络覆盖层隐藏")
	_check(_battle.tactical_network_state.overlay_visible == false, "tactical_network_state.overlay_visible 为 false")

	# 验证游戏状态未改变
	_check(unit.current_ap == ap_before, "G 切换不改变单位 AP")
	_check(unit.current_hp == hp_before, "G 切换不改变单位 HP")
	_check(unit.grid_pos == pos_before, "G 切换不改变单位位置")

	# 验证警报显示更新
	_check(_battle.alert_state != null, "alert_state 已初始化")
	_check(_battle.alert_state.get_alert_level() == AlertState.LEVEL_CALM, "初始警报等级为 calm")

	# 触发警报事件
	_battle.alert_state.apply_event("noise_detected")
	_check(_battle.alert_state.get_alert_level() == AlertState.LEVEL_SUSPICIOUS, "noise_detected 提升警报至 suspicious")
	hud.update_alert_display(_battle.alert_state)
	var alert_label: Label = hud.get_node_or_null("TopBar/AlertLabel")
	_check(alert_label != null and alert_label.visible, "警报标签可见")
	_check(alert_label != null and alert_label.get_parent() == hud.get_node("TopBar"), "警报标签挂载在顶部栏第二行")
	_check(alert_label != null and alert_label.size.x >= 300.0, "警报标签有足够宽度显示完整下一步")
	_check(alert_label != null and alert_label.text.contains("可疑"), "警报标签显示当前等级")
	_check(alert_label != null and alert_label.text.contains("下一步"), "警报标签显示下一步后果")
	_check(alert_label != null and not alert_label.text.contains("Enemies"), "警报标签不显示英文调试文案")

	# 验证警报后果数据
	var consequence: Dictionary = _battle.alert_state.get_consequence()
	_check(int(consequence.get("reinforcement_bonus", 0)) == 1, "suspicious 警报提供 1 点增援加成")
	var next_consequence: Dictionary = _battle.alert_state.get_next_consequence()
	_check(String(next_consequence.get("description", "")).contains("追击"), "下一步后果描述战斗级行为")

	# CH1-060: Alert display should show turns_until (distance to next escalation).
	_check(alert_label != null and alert_label.text.contains("回合后"), "警报标签显示回合后倒计时")

	# CH1-060: Network overlay should render connection lines and state shapes when visible.
	_battle._on_toggle_network()
	await get_tree().process_frame
	_check(_battle._network_connection_lines != null, "网络连接线列表存在")
	_check(_battle._network_shape_nodes != null, "网络状态形状字典存在")
	# If the map has network nodes, there should be shape indicators rendered.
	if _battle.tactical_network_state and _battle.tactical_network_state.get_all_nodes().size() > 0:
		_check(_battle._network_shape_nodes.size() > 0, "网络状态形状已渲染")
		_check(_battle._network_node_sprites.size() > 0, "网络节点精灵已渲染")
		var fog_visibility_ok := true
		for node_id in _battle._network_node_sprites.keys():
			var node_pos: Vector2i = _battle.tactical_network_state.get_node_position(String(node_id))
			var expected_visible: bool = _battle.visibility_state.is_cell_observed(node_pos)
			var node_sprite: Sprite2D = _battle._network_node_sprites[node_id]
			if node_sprite.visible != expected_visible:
				fog_visibility_ok = false
		_check(fog_visibility_ok, "迷雾外网络节点不泄露位置")
	_battle._on_toggle_network()

	await _dispose_battle()

## CODE-CH1-010: 玩家移动通过 commit_action 提交，预览被消费
func _test_player_move_uses_commit_action() -> void:
	print("\n--- 测试: 玩家移动通过 commit_action 提交 ---")
	GameManager.current_level_id = "ch1_m1"
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if _battle.get_script() == null:
		_check(false, "战斗脚本加载")
		await _dispose_battle()
		return
	var unit: Unit = _battle.player_units[0]
	unit.current_ap = 2
	_battle._select_unit(unit)
	await get_tree().process_frame
	var reachable: Dictionary = _battle.reachable_cells
	if reachable.is_empty():
		_check(false, "单位有可达移动格")
		await _dispose_battle()
		return
	var target_cell: Vector2i = Vector2i(-1, -1)
	for cell in reachable.keys():
		if cell != unit.grid_pos:
			target_cell = cell
			break
	if target_cell.x < 0:
		_check(false, "找到非起点可达格")
		await _dispose_battle()
		return
	var previews_before: int = _battle.action_system._active_previews.size()
	# 直接调用 _try_move（内部走 query_action → commit_action 路径）
	_battle._try_move(target_cell)
	await get_tree().process_frame
	_check(unit.grid_pos == target_cell, "玩家单位移动到目标格 (期望 %s 实际 %s)" % [target_cell, unit.grid_pos])
	# commit_action 消费了 query_action 注册的预览，_active_previews 不应增长
	var previews_after: int = _battle.action_system._active_previews.size()
	_check(previews_after <= previews_before, "移动后 _active_previews 未增长 (commit_action 消费了预览, before=%d after=%d)" % [previews_before, previews_after])
	await _dispose_battle()

func _dispose_battle() -> void:
	if _battle and is_instance_valid(_battle):
		# Units are detached data nodes. Tear this fixture down synchronously so the
		# headless runner does not exit before their scene-transition cleanup runs.
		_battle._cleanup_units()
		_battle.free()
	_battle = null
	await get_tree().process_frame

func _print_summary() -> void:
	print("\n=== 测试总结 ===")
	print("  通过: %d" % _passed)
	print("  失败: %d" % _failed)
	if _errors.size() > 0:
		print("  失败项:")
		for e in _errors:
			print("    - ", e)
	print("  =================")
