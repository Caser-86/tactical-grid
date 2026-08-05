extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2AbilityRules = preload("res://scripts/v2/combat/v2_ability_rules.gd")
const V2ActionService = preload("res://scripts/v2/combat/v2_action_service.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var assault = _make_unit("assault", "assault", Vector2i(1, 1), 7)
	var scout = _make_unit("scout", "scout", Vector2i(2, 2), 5)
	var sniper = _make_unit("sniper", "sniper", Vector2i(1, 1), 5)
	var heavy = _make_unit("heavy", "heavy", Vector2i(5, 5), 8)
	var enemy = _make_unit("enemy", "sentry", Vector2i(3, 1), 6)
	var ally = _make_unit("ally", "scout", Vector2i(6, 5), 5)
	ally.max_shield = 5

	var ctx := {"state_revision": 1}
	var impact: Dictionary = V2AbilityRules.query(assault, &"impact_advance", {"position": Vector2i(4, 1)}, {
		"state_revision": 1, "modules": ["assault_a"], "target_unit": enemy,
	})
	t.check(bool(impact.get("valid", false)) and int(impact.get("move_distance", 0)) == 3, "突击可直线推进三格")
	t.check(int(impact.get("push_distance", 0)) == 2, "延伸冲击模块增加击退距离")
	var impact_result: Dictionary = V2AbilityRules.commit(assault, impact, ctx)
	t.check(bool(impact_result.get("success", false)) and assault.grid_pos == Vector2i(4, 1), "突击能力提交移动角色")
	t.check(assault.v2_turn_state.get_cooldown(&"impact_advance") == 2 and not assault.can_act(), "突击能力消费行动并进入冷却")
	var impact_again: Dictionary = V2AbilityRules.query(assault, &"impact_advance", {"position": Vector2i(5, 1)}, {"modules": ["assault_a"]})
	t.check(not bool(impact_again.get("valid", true)) and impact_again.get("reason", &"") == &"on_cooldown", "突击能力冷却中拒绝")

	var scan: Dictionary = V2AbilityRules.query(scout, &"area_scan", {"position": Vector2i(4, 3)}, {
		"state_revision": 1, "modules": ["scout_a"],
	})
	t.check(bool(scan.get("valid", false)) and int(scan.get("reveal_radius", 0)) == 4, "侦察扫描半径受模块扩展")
	var scan_result: Dictionary = V2AbilityRules.commit(scout, scan, ctx)
	t.check(bool(scan_result.get("success", false)) and int(scan_result.get("reveal_radius", 0)) == 4, "区域扫描提交返回揭示半径")

	var interrupt: Dictionary = V2AbilityRules.query(sniper, &"interrupt_shot", {"target_unit": enemy}, {
		"state_revision": 1, "modules": ["sniper_a", "sniper_b"],
	})
	t.check(bool(interrupt.get("valid", false)) and bool(interrupt.get("cancel_intent", false)), "截断射击取消攻击意图")
	t.check(int(interrupt.get("damage", 0)) == 3 and bool(interrupt.get("mark_target", false)), "狙击模块增强伤害并标记")
	var interrupt_result: Dictionary = V2AbilityRules.commit(sniper, interrupt, ctx)
	t.check(bool(interrupt_result.get("success", false)) and enemy.current_hp == 3, "截断射击提交固定伤害")

	var barrier: Dictionary = V2AbilityRules.query(heavy, &"barrier_projection", {"target_unit": ally}, {
		"state_revision": 1, "modules": ["heavy_a", "heavy_b"], "allies": [ally],
	})
	t.check(bool(barrier.get("valid", false)) and int(barrier.get("shield", 0)) == 3, "屏障提供两点并受加固模块增强")
	t.check(int(barrier.get("target_range", 0)) == 2, "延展屏障扩大友军范围")
	var barrier_result: Dictionary = V2AbilityRules.commit(heavy, barrier, ctx)
	t.check(bool(barrier_result.get("success", false)) and ally.current_shield == 3, "屏障提交到友军")

	var wrong_role: Dictionary = V2AbilityRules.query(assault, &"area_scan", {"position": Vector2i(2, 2)}, {})
	t.check(not bool(wrong_role.get("valid", true)) and wrong_role.get("reason", &"") == &"wrong_role", "错误角色不能使用能力")

	var close_armor: Array[Dictionary] = V2AbilityRules.apply_passive(&"turn_ended", assault, {"observed_enemy_distance": 2})
	t.check(close_armor.size() == 1 and int(close_armor[0].get("shield", 0)) == 1, "贴身装甲在近距离观察触发")
	var observer: Array[Dictionary] = V2AbilityRules.apply_passive(&"enemy_revealed", scout, {})
	t.check(observer.size() == 1 and int(observer[0].get("vision_bonus", 0)) == 1, "先行观察在首次揭示触发")
	var steady: Array[Dictionary] = V2AbilityRules.apply_passive(&"before_attack_preview", sniper, {"did_move": false})
	t.check(steady.size() == 1 and int(steady[0].get("damage_bonus", 0)) == 1, "稳定射位在未移动时触发")
	var heavy_frame: Array[Dictionary] = V2AbilityRules.apply_passive(&"before_attack_taken", heavy, {"direct": true, "already_triggered": false})
	t.check(heavy_frame.size() == 1 and int(heavy_frame[0].get("damage_reduction", 0)) == 1, "重型框架每回合首次受击触发")
	var passive_blocked: Array[Dictionary] = V2AbilityRules.apply_passive(&"before_attack_taken", heavy, {"direct": true, "already_triggered": true})
	t.check(passive_blocked.is_empty(), "重型框架同回合不重复触发")

	var service_actor = _make_unit("service_assault", "assault", Vector2i(1, 1), 7)
	var action_service = V2ActionService.new()
	action_service.setup({"size": {"width": 8, "height": 8}, "layers": {"base_terrain": [], "blocker": [], "vision": [], "height": [], "cover": []}}, [service_actor], [])
	var service_preview: Dictionary = action_service.query_action({
		"action": &"ability", "ability_id": &"impact_advance", "unit": service_actor,
		"target_data": {"position": Vector2i(4, 1)}, "context": {"modules": ["assault_a"]},
	})
	t.check(bool(service_preview.get("valid", false)), "行动服务接入角色能力预览")
	var service_result: Dictionary = action_service.commit_action(service_preview)
	t.check(bool(service_result.get("success", false)) and service_actor.grid_pos == Vector2i(4, 1), "行动服务提交角色能力")

	assault.queue_free()
	scout.queue_free()
	sniper.queue_free()
	heavy.queue_free()
	enemy.queue_free()
	ally.queue_free()
	service_actor.queue_free()
	t.finish(self)

func _make_unit(id: String, role: String, position: Vector2i, hp: int):
	var unit = UnitScript.new()
	unit.entity_id = id
	unit.job = role
	unit.team = "enemy" if role == "sentry" else "player"
	unit.grid_pos = position
	unit.max_hp = hp
	unit.current_hp = hp
	unit.is_alive = true
	unit.enable_v2_turn_mode()
	return unit
