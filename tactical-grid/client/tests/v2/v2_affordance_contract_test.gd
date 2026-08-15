extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2AffordancePresenter = preload("res://scripts/v2/presentation/v2_affordance_presenter.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var presenter: V2AffordancePresenter = V2AffordancePresenter.new()
	root.add_child(presenter)
	presenter.cell_size = 64.0
	var player := _make_unit("player_assault", "player", Vector2i(2, 2))
	var enemy := _make_unit("enemy_sentry", "enemy", Vector2i(4, 2))

	var has_progressive_api := (
		presenter.has_method("show_reachable")
		and presenter.has_method("show_move_preview")
		and presenter.has_method("show_attackable")
		and presenter.has_method("show_attack_preview")
		and presenter.has_method("clear_transient")
	)
	t.check(has_progressive_api, "展示器提供渐进式持久层与瞬时层 API")
	if not has_progressive_api:
		presenter.show_for_unit(player, {
			"reachable": {Vector2i(1, 2): 1},
		}, {
			"range_cells": [Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)],
			"targets": [enemy],
		})
		t.check(_broad_red_fill_count(presenter) == 0, "旧兼容入口不得绘制全范围红色填充")
		player.free()
		enemy.free()
		presenter.free()
		t.finish(self)
		return

	presenter.call("show_reachable", {Vector2i(1, 2): 1, Vector2i(2, 3): 2})
	presenter.call("show_attackable", [enemy])
	t.check(_group_count(presenter, "v2_move_overlay") == 2, "持久层只显示真实可达的青色格")
	t.check(_group_count(presenter, "v2_attackable_outline") == 1, "持久层只描边合法敌方目标")
	t.check(_group_count(presenter, "v2_attack_range_fill") == 0, "渐进提示不绘制整片红色攻击范围")
	t.check(_range_glyph_count(presenter) == 0, "移动与攻击提示不以 M/A 字符为主")

	# Compatibility entry point must also ignore broad range_cells. Removing that
	# guard would restore the full-board red overlay that this task replaces.
	presenter.show_for_unit(player, {
		"reachable": {Vector2i(1, 2): 1},
	}, {
		"range_cells": [Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)],
		"targets": [enemy],
	})
	t.check(_group_count(presenter, "v2_move_overlay") == 1, "兼容入口保留可达格")
	t.check(_group_count(presenter, "v2_attackable_outline") == 1, "兼容入口只保留合法敌人描边")
	t.check(_group_count(presenter, "v2_attack_range_fill") == 0, "兼容入口不会恢复全范围红色填充")

	presenter.call("show_move_preview", {
		"valid": true,
		"path": [Vector2i(2, 3), Vector2i(3, 3)],
		"destination": Vector2i(3, 3),
		"dangerous": false,
		"reason": &"",
	})
	t.check(_group_count(presenter, "v2_path_overlay") == 2, "合法移动仅显示查询返回的两步路径")
	t.check(_group_count(presenter, "v2_move_destination") == 1, "合法移动显示唯一目的地形状")
	t.check(_group_count(presenter, "v2_path_line") == 1, "合法移动显示一条连续路径")

	presenter.call("clear_transient")
	t.check(_group_count(presenter, "v2_path_overlay") == 0, "清理瞬时层移除移动路径")
	t.check(_group_count(presenter, "v2_move_destination") == 0, "清理瞬时层移除目的地")
	t.check(_group_count(presenter, "v2_move_overlay") == 1, "清理瞬时层保留可达格")
	t.check(_group_count(presenter, "v2_attackable_outline") == 1, "清理瞬时层保留敌人描边")

	presenter.call("show_move_preview", {
		"valid": true,
		"path": [Vector2i(2, 3)],
		"destination": Vector2i(2, 3),
		"dangerous": false,
		"reason": &"",
	})
	t.check(_group_count(presenter, "v2_path_overlay") == 1, "相邻移动只显示查询返回的一格路径")
	t.check(_group_count(presenter, "v2_move_destination") == 1, "相邻移动仍显示唯一目的地形状")

	presenter.call("show_move_preview", {
		"valid": true,
		"path": [Vector2i(2, 3), Vector2i(3, 3)],
		"destination": Vector2i(3, 3),
		"dangerous": true,
		"reason": &"dangerous",
	})
	t.check(_group_count(presenter, "v2_path_overlay") == 0, "危险目标不显示可直接提交的路径")
	t.check(_group_count(presenter, "v2_danger_destination") == 1, "危险目标只显示警戒目的地形状")

	presenter.call("show_attack_preview", {
		"valid": true,
		"target": enemy,
		"damage": 3,
		"hp_after": 4,
		"intent_change": &"suppressed",
		"reason": &"",
	})
	t.check(_group_count(presenter, "v2_attack_preview") == 1, "攻击悬停只显示一个确定目标预览")
	t.check(_attack_preview_metadata_matches(presenter, "enemy_sentry", 3, 4), "攻击预览暴露目标、伤害和剩余 HP")
	t.check(_group_count(presenter, "v2_intent_change_cue") == 1, "意图改变使用独立形状提示")
	t.check(_group_count(presenter, "v2_attack_range_fill") == 0, "攻击预览不会生成全板红色填充")

	presenter.clear_all()
	t.check(presenter.get_child_count() == 0, "清理全部同时移除持久层和瞬时层")

	presenter.free()
	player.free()
	enemy.free()
	t.finish(self)

func _make_unit(id: String, team: String, cell: Vector2i) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = id
	unit.unit_name = id
	unit.team = team
	unit.grid_pos = cell
	unit.max_hp = 7
	unit.current_hp = 7
	unit.is_alive = true
	return unit

func _group_count(node: Node, group_name: StringName) -> int:
	var count := 0
	for child in node.get_children():
		if child.is_in_group(group_name):
			count += 1
	return count

func _range_glyph_count(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is Label and String(child.text) in ["M", "A"]:
			count += 1
	return count

func _broad_red_fill_count(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is ColorRect and child.is_in_group("v2_attack_overlay"):
			count += 1
	return count

func _attack_preview_metadata_matches(node: Node, target_id: String, damage: int, hp_after: int) -> bool:
	for child in node.get_children():
		if not child.is_in_group("v2_attack_preview"):
			continue
		return (
			String(child.get_meta("v2_target_id", "")) == target_id
			and int(child.get_meta("v2_damage", -1)) == damage
			and int(child.get_meta("v2_hp_after", -1)) == hp_after
		)
	return false
