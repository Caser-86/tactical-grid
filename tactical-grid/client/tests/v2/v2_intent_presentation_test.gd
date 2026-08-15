extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Presenter = preload("res://scripts/v2/presentation/v2_intent_presenter.gd")

var t := Runner.new()

func _initialize() -> void:
	var attack := Presenter.build({
		"type": "attack",
		"target_id": "enemy_a",
		"target_cell": Vector2i(4, 2),
		"damage": 3,
		"telegraph": "",
	})
	var scan := Presenter.build({
		"type": "scan",
		"target_id": "",
		"target_cell": Vector2i(8, 4),
		"radius": 3,
		"telegraph": "scan_pulse",
	})
	var protect := Presenter.build({
		"type": "protect",
		"target_id": "enemy_guarded",
		"target_cell": Vector2i(6, 5),
		"protect_reduction": 1,
		"telegraph": "shield_link",
	})
	var guard := Presenter.build({
		"type": "guard",
		"target_id": "",
		"target_cell": Vector2i(5, 5),
		"fallback_reason": "no_legal_firing_line",
	})

	t.check(attack.get("shape", "") == "arrow", "攻击意图使用箭头形状")
	t.check(attack.get("line_cells", []).size() >= 1, "攻击意图保留可绘制射线数据")
	t.check(attack.get("target_cell", Vector2i(-1, -1)) == Vector2i(4, 2), "攻击意图保留目标格")
	t.check(attack.get("damage_text", "") == "伤害 3", "攻击意图提供预期伤害文本")
	t.check(scan.get("shape", "") == "cone", "扫描意图使用扇形/锥形")
	t.check(scan.get("pulse", false), "扫描意图带脉冲反馈")
	t.check(protect.get("shape", "") == "link", "保护意图使用连接形状")
	t.check(protect.get("icon_key", "") == "shield", "保护意图使用盾牌图标语义")
	t.check(guard.get("shape", "") == "guard", "守卫意图使用非指向性标记")
	t.check(String(guard.get("target_id", "")) == "", "守卫意图不伪造目标")

	var shapes := {}
	for result in [attack, scan, protect, guard]:
		shapes[String(result.get("shape", ""))] = true
	t.check(shapes.size() == 4, "攻击、扫描、保护、守卫形状即使去掉颜色仍可区分")

	t.finish(self)
