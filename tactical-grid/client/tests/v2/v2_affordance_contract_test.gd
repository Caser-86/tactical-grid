extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2AffordancePresenter = preload("res://scripts/v2/presentation/v2_affordance_presenter.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var presenter: V2AffordancePresenter = V2AffordancePresenter.new()
	root.add_child(presenter)
	presenter.cell_size = 64.0
	var unit: Unit = UnitScript.new()
	unit.entity_id = "player_assault"
	unit.team = "player"
	unit.grid_pos = Vector2i(2, 2)
	unit.current_hp = 7
	unit.max_hp = 7
	unit.is_alive = true

	presenter.show_for_unit(unit, {
		"reachable": {Vector2i(1, 2): {}, Vector2i(2, 3): {}},
	}, {
		"range_cells": [Vector2i(3, 2), Vector2i(2, 4)],
		"targets": [unit, Vector2i(4, 2)],
	})
	t.check(_group_count(presenter, "v2_move_overlay") == 2, "选择后生成蓝色移动格")
	t.check(_group_count(presenter, "v2_attack_overlay") >= 4, "选择后同时生成红色攻击范围和目标")
	t.check(_group_count(presenter, "v2_danger_overlay") == 0, "普通选择不显示危险路径")

	presenter.show_path([Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4)], true)
	t.check(_group_count(presenter, "v2_path_overlay") == 2, "路径不重复绘制起点")
	t.check(_group_count(presenter, "v2_danger_overlay") == 2, "危险路径使用独立标记")

	presenter.clear_preview()
	t.check(_group_count(presenter, "v2_path_overlay") == 0, "清理预览移除路径")
	t.check(_group_count(presenter, "v2_danger_overlay") == 0, "清理预览移除危险标记")
	t.check(_group_count(presenter, "v2_move_overlay") == 2, "清理预览保留范围")

	presenter.clear_all()
	t.check(_group_count(presenter, "v2_move_overlay") == 0, "清理全部移除移动范围")
	t.check(_group_count(presenter, "v2_attack_overlay") == 0, "清理全部移除攻击范围")

	presenter.free()
	unit.free()
	t.finish(self)

func _group_count(node: Node, group_name: StringName) -> int:
	var count := 0
	for child in node.get_children():
		if child.is_in_group(group_name):
			count += 1
	return count
