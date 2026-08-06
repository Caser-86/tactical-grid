extends Node

const BattleScene = preload("res://scenes/v2_battle.tscn")
const BattleControllerScript = preload("res://scripts/v2/runtime/v2_battle_controller.gd")
const Runner = preload("res://tests/v2/test_runner.gd")

var t := Runner.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = get_node_or_null("/root/GameManager")
	t.check(manager != null, "控制器回归使用正式 GameManager fixture")
	if manager == null:
		t.finish(get_tree())
		return
	manager.call("begin_v2_new_game_for_test", 0)
	manager.set("current_level_id", "ch1_m1")
	var battle := BattleScene.instantiate()
	t.check(battle != null and battle.get_script() == BattleControllerScript, "实例化正式 V2 battle.tscn 控制器")
	if battle == null:
		t.finish(get_tree())
		return
	add_child(battle)
	await _dismiss_intro(manager)
	var ready := await _wait_for_player_phase(battle)
	t.check(ready, "正式 V2 控制器进入玩家行动阶段")
	if not ready:
		await _cleanup_battle(battle)
		t.finish(get_tree())
		return

	var old_live_id := "enemy_sentry_south"
	var old_live := _find_enemy(battle, old_live_id)
	t.check(old_live != null and old_live.is_alive and battle.call("_get_unit_sprite", old_live) != null, "第一遭遇的旧存活 Unit 和精灵已进入运行时")

	var second_delta: Dictionary = battle.call("_update_v2_encounters", [{"event": "enter_rescue_radius"}])
	var second_active: Array = battle.v2_encounter_activation.get_active_enemy_ids()
	var second_waiting: Array = battle.v2_encounter_activation.get_waiting_enemy_ids()
	t.check(second_delta.get("success", false), "第二遭遇通过真实控制器 delta 事务触发")
	t.check(second_active.has(old_live_id) and old_live.is_alive and battle.call("_get_unit_sprite", old_live) != null, "第二遭遇保留旧存活 Unit 和精灵")
	t.check(second_active.size() == 3 and second_waiting.size() == 2, "第二遭遇严格遵守 active_cap 并保留等待溢出")

	var defeated := _find_live_enemy_other_than(battle, old_live_id)
	var defeated_id := defeated.entity_id if defeated != null else ""
	defeated.take_damage(defeated.current_hp + defeated.current_shield + 1)
	await get_tree().process_frame
	var defeated_result: Dictionary = {
		"success": battle.v2_encounter_activation.get_defeated_enemy_ids().has(defeated_id),
	}
	var defeated_cell: Vector2i = defeated.grid_pos if defeated != null else Vector2i(-1, -1)
	battle.call("_update_v2_encounters", [])
	t.check(bool(defeated_result.get("success", false)), "活动敌人击败状态登记成功")
	t.check(defeated != null and not defeated.is_alive and defeated.is_downed, "击败 Unit 保留 defeated 生命周期")
	t.check(battle.call("_get_unit_sprite", defeated) == null and not battle.call("_get_v2_live_enemy_ids").has(defeated_id), "击败清理移除精灵并退出活动运行时 roster")
	t.check(not _service_occupies(battle, defeated_cell), "击败 Unit 释放 V2ActionService occupancy")

	var promoted: Array = battle.v2_encounter_activation.get_active_enemy_ids()
	var waiting_after_defeat: Array = battle.v2_encounter_activation.get_waiting_enemy_ids()
	var promoted_waiting_id := ""
	for raw_id in second_waiting:
		var candidate_id := String(raw_id)
		if promoted.has(candidate_id):
			promoted_waiting_id = candidate_id
			break
	t.check(not promoted_waiting_id.is_empty() and not waiting_after_defeat.has(promoted_waiting_id), "击败后等待队列按稳定顺序晋升")
	t.check(_live_positions_are_unique_and_player_safe(battle), "等待晋升只使用不与玩家和存活敌人重叠的格子")

	var waiting_departed_id := String(waiting_after_defeat[0]) if not waiting_after_defeat.is_empty() else ""
	var waiting_departed := _find_enemy(battle, waiting_departed_id)
	var active_departed := old_live
	var waiting_cell: Vector2i = waiting_departed.grid_pos if waiting_departed != null else Vector2i(-1, -1)
	var active_cell: Vector2i = active_departed.grid_pos if active_departed != null else Vector2i(-1, -1)
	var waiting_departure_result: Dictionary = battle.v2_encounter_activation.mark_enemy_departed(waiting_departed_id)
	var active_departure_result: Dictionary = battle.v2_encounter_activation.mark_enemy_departed(old_live_id)
	t.check(bool(waiting_departure_result.get("success", false)) and bool(active_departure_result.get("success", false)), "活动和等待敌人均可登记离场")
	t.check(_service_occupies(battle, waiting_cell) and _service_occupies(battle, active_cell), "离场清理前真实 V2ActionService 仍观察到待释放的旧占位")
	battle.call("_update_v2_encounters", [])
	t.check(waiting_departed != null and not waiting_departed.is_alive and waiting_departed.is_downed, "等待离场 Unit 在真实控制器事务中变为 occupancy-free")
	t.check(active_departed != null and not active_departed.is_alive and active_departed.is_downed, "活动离场 Unit 在真实控制器事务中变为 occupancy-free")
	t.check(not _service_occupies(battle, waiting_cell) and not _service_occupies(battle, active_cell), "活动和等待离场均释放 V2ActionService occupancy")
	await get_tree().process_frame
	t.check(battle.call("_get_unit_sprite", waiting_departed) == null and battle.call("_get_unit_sprite", active_departed) == null, "活动和等待离场均移除精灵")
	t.check(not battle.call("_get_v2_live_enemy_ids").has(waiting_departed_id) and not battle.call("_get_v2_live_enemy_ids").has(old_live_id), "活动运行时 roster 排除活动和等待离场 Unit")
	t.check(battle.enemy_units.has(waiting_departed) and battle.enemy_units.has(active_departed), "稳定 enemy_units roster 仍保留可存档 Unit 身份")

	var active_before_repeat: Array = battle.v2_encounter_activation.get_active_enemy_ids()
	var waiting_before_repeat: Array = battle.v2_encounter_activation.get_waiting_enemy_ids()
	var defeated_before_repeat: Array = battle.v2_encounter_activation.get_defeated_enemy_ids()
	var departed_before_repeat: Array = battle.v2_encounter_activation.get_departed_enemy_ids()
	battle.call("_update_v2_encounters", [])
	t.check(active_before_repeat == battle.v2_encounter_activation.get_active_enemy_ids(), "重复 update 不改变活动集合")
	t.check(waiting_before_repeat == battle.v2_encounter_activation.get_waiting_enemy_ids(), "重复 update 不改变等待集合")
	t.check(defeated_before_repeat == battle.v2_encounter_activation.get_defeated_enemy_ids() and departed_before_repeat == battle.v2_encounter_activation.get_departed_enemy_ids(), "重复 update 不复活击败/离场敌人")
	t.check(_sprite_count(battle, defeated_id) == 0 and _sprite_count(battle, old_live_id) == 0 and _sprite_count(battle, promoted_waiting_id) == 1, "重复 update 不重复生成或恢复精灵")

	await _cleanup_battle(battle)
	t.finish(get_tree())

func _find_enemy(battle: Node, entity_id: String) -> Unit:
	for raw_unit in battle.enemy_units:
		var unit: Unit = raw_unit
		if unit != null and unit.entity_id == entity_id:
			return unit
	return null

func _find_live_enemy_other_than(battle: Node, excluded_id: String) -> Unit:
	for raw_unit in battle.enemy_units:
		var unit: Unit = raw_unit
		if unit != null and unit.is_alive and unit.entity_id != excluded_id:
			return unit
	return null

func _service_occupies(battle: Node, cell: Vector2i) -> bool:
	return cell.x >= 0 and bool(battle.v2_action_service.call("_is_occupied", cell, null))

func _sprite_count(battle: Node, entity_id: String) -> int:
	var count := 0
	for child in battle.unit_layer.get_children():
		if child is UnitSprite and child.unit != null and child.unit.entity_id == entity_id:
			count += 1
	return count

func _live_positions_are_unique_and_player_safe(battle: Node) -> bool:
	var occupied := {}
	for raw_unit in battle.player_units + battle.enemy_units:
		var unit: Unit = raw_unit
		if unit == null or not unit.is_alive:
			continue
		if occupied.has(unit.grid_pos):
			return false
		occupied[unit.grid_pos] = true
	return true

func _dismiss_intro(manager: Node) -> void:
	for _i in range(30):
		await get_tree().process_frame
		var dialogue: Node = manager.get("_active_dialogue")
		if dialogue != null and is_instance_valid(dialogue):
			dialogue.call("_end_dialogue")
			await get_tree().process_frame
			return

func _wait_for_player_phase(battle: Node) -> bool:
	for _i in range(180):
		if battle.turn_manager != null and battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION:
			return true
		await get_tree().process_frame
	return false

func _cleanup_battle(battle: Node) -> void:
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
		await get_tree().process_frame
