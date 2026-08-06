extends Node

const Runner = preload("res://tests/v2/test_runner.gd")
const UnitScript = preload("res://scripts/game/unit.gd")
const UnitSpriteScript = preload("res://scripts/game/unit_sprite.gd")

var t := Runner.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var unit: Unit = UnitScript.new()
	unit.entity_id = "enemy_sync"
	unit.team = "enemy"
	unit.unit_name = "测试敌人"
	unit.is_alive = true
	unit.current_hp = 4
	unit.max_hp = 4
	var sprite: UnitSprite = UnitSpriteScript.new()
	add_child(sprite)
	sprite.update_unit(unit)
	sprite.position = Vector2.ZERO
	sprite.play_move_to(Vector2(64, 0), 0.20)
	await get_tree().process_frame
	# This mirrors occupancy reconciliation correcting a stale visual position.
	sprite.snap_to(Vector2(128, 0))
	await get_tree().create_timer(0.25).timeout
	t.check(sprite.position == Vector2(128, 0), "位置纠正后移动 Tween 不得把敌人精灵拉回旧格")
	sprite.queue_free()
	unit.free()
	t.finish(get_tree())
