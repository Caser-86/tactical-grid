extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var preview_script := ResourceLoader.load("res://scripts/v2/presentation/v2_action_preview.gd") as Script
	t.check(preview_script != null, "纯行动预览构建器可加载")
	if preview_script == null:
		t.finish(self)
		return
	var builder: RefCounted = preview_script.new()
	var actor := _make_unit("player_assault", "player", Vector2i(1, 1), 7)
	var enemy := _make_unit("enemy_sentry", "enemy", Vector2i(3, 1), 7)
	var legal_path: Array[Vector2i] = [Vector2i(2, 1), Vector2i(3, 1)]

	var move_query := {
		"valid": true,
		"target": Vector2i(3, 1),
		"path": legal_path,
		"dangerous": false,
	}
	var move: Dictionary = builder.call("build_move", actor, Vector2i(3, 1), move_query)
	t.check(_same_keys(move, ["valid", "path", "destination", "dangerous", "reason"]), "移动预览只暴露规定的五个合同键")
	t.check(bool(move.get("valid", false)), "合法移动查询生成可见预览")
	t.check(move.get("path", []) == legal_path, "移动预览逐点复用提交查询的真实路径")
	t.check(move.get("destination", Vector2i(-1, -1)) == Vector2i(3, 1), "移动预览目的地与请求格一致")
	t.check(not bool(move.get("dangerous", true)) and move.get("reason", &"bad") == &"", "安全移动预览保留安全状态")

	var mismatched: Dictionary = builder.call("build_move", actor, Vector2i(3, 1), {
		"valid": true,
		"target": Vector2i(4, 1),
		"path": [Vector2i(2, 1), Vector2i(4, 1)],
	})
	t.check(not bool(mismatched.get("valid", true)) and mismatched.get("path", []).is_empty(), "查询目的地不匹配时不暴露误导路径")
	t.check(mismatched.get("reason", &"") == &"destination_mismatch", "目的地不匹配返回稳定原因")

	var broken_path: Dictionary = builder.call("build_move", actor, Vector2i(3, 1), {
		"valid": true,
		"target": Vector2i(3, 1),
		"path": [Vector2i(2, 1)],
	})
	t.check(not bool(broken_path.get("valid", true)) and broken_path.get("reason", &"") == &"path_destination_mismatch", "不以目标格结束的查询路径被拒绝")

	var dangerous: Dictionary = builder.call("build_move", actor, Vector2i(3, 1), {
		"valid": true,
		"target": Vector2i(3, 1),
		"path": legal_path,
		"dangerous": true,
	})
	t.check(bool(dangerous.get("valid", false)) and bool(dangerous.get("dangerous", false)), "危险合法格保留危险状态供展示层降级")

	var invalid_move: Dictionary = builder.call("build_move", actor, Vector2i(3, 1), {"valid": false, "reason": &"occupied"})
	t.check(not bool(invalid_move.get("valid", true)) and invalid_move.get("path", []).is_empty(), "无效移动查询永不返回路径")
	t.check(invalid_move.get("reason", &"") == &"occupied", "无效移动保留服务层原因")

	var attack_query := {
		"valid": true,
		"target_unit": enemy,
		"final_damage": 3,
		"hp_after": 4,
		"intent_change": &"suppressed",
	}
	var attack: Dictionary = builder.call("build_attack", actor, enemy, attack_query)
	t.check(_same_keys(attack, ["valid", "target", "damage", "hp_after", "intent_change", "reason"]), "攻击预览只暴露规定的六个合同键")
	t.check(bool(attack.get("valid", false)) and attack.get("target") == enemy, "合法攻击预览保留确定目标身份")
	t.check(int(attack.get("damage", -1)) == 3 and int(attack.get("hp_after", -1)) == 4, "攻击预览复用提交查询的伤害与剩余 HP")
	t.check(attack.get("intent_change", &"") == &"suppressed" and attack.get("reason", &"bad") == &"", "攻击预览保留意图变化信息")

	var wrong_target: Dictionary = builder.call("build_attack", actor, enemy, {
		"valid": true,
		"target_unit": actor,
		"final_damage": 3,
		"hp_after": 4,
	})
	t.check(not bool(wrong_target.get("valid", true)) and wrong_target.get("target") == null, "查询目标不匹配时不展示错误敌人")
	t.check(wrong_target.get("reason", &"") == &"target_mismatch", "攻击目标不匹配返回稳定原因")

	var invalid_attack: Dictionary = builder.call("build_attack", actor, enemy, {"valid": false, "reason": &"out_of_range"})
	t.check(not bool(invalid_attack.get("valid", true)) and invalid_attack.get("target") == null, "无效攻击不暴露目标预览")
	t.check(invalid_attack.get("reason", &"") == &"out_of_range", "无效攻击保留服务层原因")

	actor.free()
	enemy.free()
	t.finish(self)

func _make_unit(id: String, team: String, cell: Vector2i, hp: int) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = id
	unit.unit_name = id
	unit.team = team
	unit.grid_pos = cell
	unit.max_hp = hp
	unit.current_hp = hp
	unit.is_alive = true
	return unit

func _same_keys(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true
