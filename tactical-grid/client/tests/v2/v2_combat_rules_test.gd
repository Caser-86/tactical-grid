extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2CombatRules = preload("res://scripts/v2/combat/v2_combat_rules.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var attacker = _make_unit("attacker", "player", 10, 0)
	var target = _make_unit("target", "enemy", 4, 0)
	attacker.weapon_range = [1, 5]
	attacker.weapon_damage = [3, 3]

	var plain: Dictionary = V2CombatRules.preview_attack(attacker, target, {
		"has_los": true, "distance": 3, "cover": &"none", "flanked": false, "state_revision": 1,
	})
	t.check(bool(plain.get("valid", false)) and int(plain.get("final_damage", 0)) == 3 and int(plain.get("hp_after", 0)) == 1, "无掩体造成固定三伤")

	var half: Dictionary = V2CombatRules.preview_attack(attacker, target, {
		"has_los": true, "distance": 3, "cover": &"half", "flanked": false, "state_revision": 1,
	})
	t.check(int(half.get("cover_reduction", 0)) == 1 and int(half.get("final_damage", 0)) == 2, "半掩体减一")

	var full: Dictionary = V2CombatRules.preview_attack(attacker, target, {
		"has_los": true, "distance": 3, "cover": &"full", "flanked": false, "state_revision": 1,
	})
	t.check(not bool(full.get("valid", true)) and full.get("reason", &"") == &"full_cover", "全掩体阻挡正面攻击")

	var flank: Dictionary = V2CombatRules.preview_attack(attacker, target, {
		"has_los": true, "distance": 3, "cover": &"full", "flanked": true, "state_revision": 1,
	})
	t.check(bool(flank.get("valid", false)) and int(flank.get("final_damage", 0)) == 3, "侧翼忽略掩体")

	var no_los: Dictionary = V2CombatRules.preview_attack(attacker, target, {
		"has_los": false, "distance": 3, "cover": &"none", "flanked": false, "state_revision": 1,
	})
	t.check(not bool(no_los.get("valid", true)) and no_los.get("reason", &"") == &"no_line_of_sight", "无视线拒绝攻击")

	var out_of_range: Dictionary = V2CombatRules.preview_attack(attacker, target, {
		"has_los": true, "distance": 6, "cover": &"none", "flanked": false, "state_revision": 1,
	})
	t.check(not bool(out_of_range.get("valid", true)) and out_of_range.get("reason", &"") == &"out_of_range", "超出射程拒绝攻击")

	target.current_shield = 2
	target.armor = 2
	var shielded: Dictionary = V2CombatRules.preview_attack(attacker, target, {
		"has_los": true, "distance": 3, "cover": &"none", "flanked": false, "state_revision": 7,
	})
	t.check(int(shielded.get("armor_reduction", 0)) == 2 and int(shielded.get("shield_absorb", 0)) == 1, "护甲和护盾分开展示")
	t.check(int(shielded.get("hp_after", 0)) == 4 and int(shielded.get("state_revision", 0)) == 7, "预览不修改目标并回传状态版本")
	t.check(shielded.get("attacker_id", "") == "attacker" and shielded.get("target_id", "") == "target", "预览包含稳定单位 ID")

	var self_result: Dictionary = V2CombatRules.preview_attack(attacker, attacker, {
		"has_los": true, "distance": 1, "cover": &"none", "flanked": false, "state_revision": 1,
	})
	t.check(not bool(self_result.get("valid", true)) and self_result.get("reason", &"") == &"same_unit", "自身目标拒绝攻击")

	var same_team = _make_unit("ally", "player", 4, 0)
	var same_result: Dictionary = V2CombatRules.preview_attack(attacker, same_team, {
		"has_los": true, "distance": 3, "cover": &"none", "flanked": false, "state_revision": 1,
	})
	t.check(not bool(same_result.get("valid", true)) and same_result.get("reason", &"") == &"same_team", "同阵营目标拒绝攻击")

	target.is_alive = false
	var dead_result: Dictionary = V2CombatRules.preview_attack(attacker, target, {
		"has_los": true, "distance": 3, "cover": &"none", "flanked": false, "state_revision": 1,
	})
	t.check(not bool(dead_result.get("valid", true)) and dead_result.get("reason", &"") == &"target_dead", "死亡目标拒绝攻击")

	var baseline: Dictionary = V2CombatRules.preview_attack(attacker, same_team, {
		"has_los": true, "distance": 3, "cover": &"none", "flanked": false, "state_revision": 9,
	})
	var stable := true
	for _i in range(100):
		var repeated: Dictionary = V2CombatRules.preview_attack(attacker, same_team, {
			"has_los": true, "distance": 3, "cover": &"none", "flanked": false, "state_revision": 9,
		})
		if JSON.stringify(repeated) != JSON.stringify(baseline):
			stable = false
	t.check(stable, "同一攻击预览重复一百次完全一致")
	t.check(not baseline.has("hit_chance") and not baseline.has("critical") and not baseline.has("dodge"), "预览不包含随机战斗字段")

	attacker.queue_free()
	target.queue_free()
	same_team.queue_free()
	t.finish(self)

func _make_unit(id: String, team: String, hp: int, armor_value: int):
	var unit = UnitScript.new()
	unit.entity_id = id
	unit.team = team
	unit.max_hp = hp
	unit.current_hp = hp
	unit.armor = armor_value
	unit.is_alive = true
	return unit
