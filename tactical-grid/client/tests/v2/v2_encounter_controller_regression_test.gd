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
	var save: Dictionary = manager.call("begin_v2_new_game_for_test", 0)
	manager.set("current_level_id", "ch1_m1")
	manager.set("current_save", _with_known_tutorials(save))
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

	var old_live_id := "m1_sentry_south"
	var old_live := _find_enemy(battle, old_live_id)
	t.check(old_live != null and old_live.is_alive and battle.call("_get_unit_sprite", old_live) != null, "教学遭遇的存活 Unit 和精灵已进入运行时")
	var assault: Unit = battle.player_units[0] if not battle.player_units.is_empty() else null
	if assault != null:
		assault.grid_pos = Vector2i(15, 8)
		battle.call("_update_unit_sprite_pos", assault, false)

	var second_delta: Dictionary = battle.call("_update_v2_encounters", [])
	var second_active: Array = battle.v2_encounter_activation.get_active_enemy_ids()
	var second_waiting: Array = battle.v2_encounter_activation.get_waiting_enemy_ids()
	t.check(second_delta.get("success", false), "救援遭遇通过空间触发进入真实控制器 delta")
	t.check(second_active.has(old_live_id) and old_live.is_alive and battle.call("_get_unit_sprite", old_live) != null, "救援遭遇保留旧存活 Unit 和精灵")
	t.check(second_active.size() == 3 and second_waiting.size() == 2, "救援遭遇严格遵守 active_cap 并保留等待溢出")

	var first_waiting_departed_id := String(second_waiting[0]) if not second_waiting.is_empty() else ""
	var second_waiting_departed_id := String(second_waiting[1]) if second_waiting.size() > 1 else ""
	var first_waiting_departed := _find_enemy(battle, first_waiting_departed_id)
	var second_waiting_departed := _find_enemy(battle, second_waiting_departed_id)
	var first_waiting_cell: Vector2i = first_waiting_departed.grid_pos if first_waiting_departed != null else Vector2i(-1, -1)
	var second_waiting_cell: Vector2i = second_waiting_departed.grid_pos if second_waiting_departed != null else Vector2i(-1, -1)
	if assault != null:
		assault.grid_pos = Vector2i(20, 4)
		battle.call("_update_unit_sprite_pos", assault, false)
	var evac_delta: Dictionary = battle.call("_update_v2_encounters", [{"event": "pre_evac"}])
	var evac_waiting: Array = battle.v2_encounter_activation.get_waiting_enemy_ids()
	t.check(evac_delta.get("success", false), "撤离防线通过空间/事件触发进入真实控制器 delta")
	t.check(evac_delta.get("deactivated_ids", []).has(first_waiting_departed_id) and evac_delta.get("deactivated_ids", []).has(second_waiting_departed_id), "撤离防线报告 waiting 离场 deactivated_ids")
	t.check(first_waiting_departed != null and not first_waiting_departed.is_alive and first_waiting_departed.is_downed, "第一名真实触发离场 Unit 变为 occupancy-free")
	t.check(second_waiting_departed != null and not second_waiting_departed.is_alive and second_waiting_departed.is_downed, "第二名真实触发离场 Unit 变为 occupancy-free")
	t.check(not _service_occupies(battle, first_waiting_cell) and not _service_occupies(battle, second_waiting_cell), "真实触发离场释放 V2ActionService occupancy")
	t.check(evac_waiting.size() >= 2, "真实离场后仍保留撤离防线 waiting 敌人")
	await get_tree().process_frame
	t.check(battle.call("_get_v2_enemy_unit", first_waiting_departed_id) == first_waiting_departed and battle.call("_get_unit_sprite", first_waiting_departed) == null, "真实触发离场保留稳定 Unit 身份且不生成精灵")
	t.check(battle.call("_get_v2_enemy_unit", second_waiting_departed_id) == second_waiting_departed and battle.call("_get_unit_sprite", second_waiting_departed) == null, "第二名真实触发离场保留稳定 Unit 身份且不生成精灵")
	t.check(not battle.call("_get_v2_live_enemy_ids").has(first_waiting_departed_id) and not battle.call("_get_v2_live_enemy_ids").has(second_waiting_departed_id), "活动运行时 roster 排除真实触发离场 Unit")

	var defeated := _find_live_enemy_other_than(battle, old_live_id)
	if defeated == null:
		t.check(false, "撤离防线应保留至少一名可击败活动敌人")
		await _cleanup_battle(battle)
		t.finish(get_tree())
		return
	var defeated_id := defeated.entity_id if defeated != null else ""
	defeated.take_damage(defeated.current_hp + defeated.current_shield + 1)
	await get_tree().process_frame
	var defeated_result: Dictionary = {
		"success": battle.v2_encounter_activation.get_defeated_enemy_ids().has(defeated_id),
	}
	var defeated_cell: Vector2i = defeated.grid_pos if defeated != null else Vector2i(-1, -1)
	t.check(bool(defeated_result.get("success", false)), "活动敌人击败状态登记成功")
	t.check(defeated != null and not defeated.is_alive and defeated.is_downed, "击败 Unit 保留 defeated 生命周期")
	t.check(battle.call("_get_unit_sprite", defeated) == null and not battle.call("_get_v2_live_enemy_ids").has(defeated_id), "击败清理移除精灵并退出活动运行时 roster")
	t.check(not _service_occupies(battle, defeated_cell), "击败 Unit 释放 V2ActionService occupancy")

	var promoted_after_departure: Array = battle.v2_encounter_activation.get_active_enemy_ids()
	var waiting_after_departure: Array = battle.v2_encounter_activation.get_waiting_enemy_ids()
	var promoted_after_departure_id := ""
	for raw_id in evac_waiting:
		var candidate_id := String(raw_id)
		if promoted_after_departure.has(candidate_id):
			promoted_after_departure_id = candidate_id
			break
	t.check(not promoted_after_departure_id.is_empty() and not waiting_after_departure.has(promoted_after_departure_id), "真实离场后的新 waiting 敌人通过控制器填充释放的 active 槽位")
	t.check(not promoted_after_departure.has(defeated_id) and not promoted_after_departure.has(first_waiting_departed_id) and not promoted_after_departure.has(second_waiting_departed_id), "击败和真实离场 ID 不被后续晋升重新激活")
	t.check(old_live.is_alive and battle.call("_get_unit_sprite", old_live) != null, "后续晋升仍保留旧存活 Unit 身份和精灵")
	t.check(_live_positions_are_unique_and_player_safe(battle), "真实触发后的等待晋升只使用不与玩家和存活敌人重叠的格子")
	t.check(battle.enemy_units.has(first_waiting_departed) and battle.enemy_units.has(second_waiting_departed), "真实触发离场仍保留稳定 enemy_units roster 身份")
	t.check(_active_runtime_matches_service(battle), "新 active roster 的精灵和 V2ActionService occupancy 一致")

	var repeated_evac_delta: Dictionary = battle.call("_update_v2_encounters", [{"event": "pre_evac"}])
	var repeated_evac_waiting: Array = battle.v2_encounter_activation.get_waiting_enemy_ids()
	t.check(repeated_evac_delta.get("success", false) and not repeated_evac_waiting.is_empty(), "重复撤离更新保持真实控制器 waiting")
	t.check(_active_runtime_matches_service(battle), "后续遭遇后 active roster 与精灵和 occupancy 保持一致")

	var active_before_repeat: Array = battle.v2_encounter_activation.get_active_enemy_ids()
	var waiting_before_repeat: Array = battle.v2_encounter_activation.get_waiting_enemy_ids()
	var defeated_before_repeat: Array = battle.v2_encounter_activation.get_defeated_enemy_ids()
	var departed_before_repeat: Array = battle.v2_encounter_activation.get_departed_enemy_ids()
	battle.call("_update_v2_encounters", [{"event": "pre_evac"}])
	t.check(active_before_repeat == battle.v2_encounter_activation.get_active_enemy_ids(), "重复 update 不改变活动集合")
	t.check(waiting_before_repeat == battle.v2_encounter_activation.get_waiting_enemy_ids(), "重复 update 不改变等待集合")
	t.check(defeated_before_repeat == battle.v2_encounter_activation.get_defeated_enemy_ids() and departed_before_repeat == battle.v2_encounter_activation.get_departed_enemy_ids(), "重复 update 不复活击败/离场敌人")
	t.check(_sprite_count(battle, defeated_id) == 0 and _sprite_count(battle, first_waiting_departed_id) == 0 and _sprite_count(battle, second_waiting_departed_id) == 0 and _sprite_count(battle, old_live_id) == 1 and _sprite_count(battle, promoted_after_departure_id) == 1, "重复 update 不重复生成或恢复精灵")
	t.check(_active_runtime_matches_service(battle), "重复 update 不改变 active roster 与服务占位")

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
		if child is UnitSprite and not child.is_ghost and child.unit != null and child.unit.entity_id == entity_id:
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

func _active_runtime_matches_service(battle: Node) -> bool:
	for raw_id in battle.v2_encounter_activation.get_active_enemy_ids():
		var entity_id := String(raw_id)
		var unit := _find_enemy(battle, entity_id)
		var sprite_count := _sprite_count(battle, entity_id)
		var service_occupied := unit != null and _service_occupies(battle, unit.grid_pos)
		if unit == null or not unit.is_alive or sprite_count != 1 or not service_occupied:
			return false
	for raw_id in battle.v2_encounter_activation.get_defeated_enemy_ids() + battle.v2_encounter_activation.get_departed_enemy_ids():
		var entity_id := String(raw_id)
		var unit := _find_enemy(battle, entity_id)
		var sprite_count := _sprite_count(battle, entity_id)
		var service_occupied := unit != null and _service_occupies(battle, unit.grid_pos)
		if unit != null and (sprite_count != 0 or service_occupied):
			return false
	return true

func _dismiss_intro(manager: Node) -> void:
	for _i in range(30):
		await get_tree().process_frame
		var dialogue: Node = manager.get("_active_dialogue")
		if dialogue != null and is_instance_valid(dialogue):
			dialogue.call("_end_dialogue")
			await get_tree().process_frame
			return

func _with_known_tutorials(save: Dictionary) -> Dictionary:
	var next := save.duplicate(true)
	var progress: Dictionary = next.get("campaign_progress", {})
	var flags: Dictionary = progress.get("story_flags", {})
	for flag in ["teach_selection", "teach_movement", "teach_attack", "teach_observe", "teach_network_takeover", "teach_end_turn"]:
		flags["tutorial_" + flag] = true
	progress["story_flags"] = flags
	next["campaign_progress"] = progress
	return next

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
