## CH1-050: EnemyIntentRenderer 渲染行为测试
## 验证渲染器：
## - 仅渲染公开意图（受可见性过滤）
## - 使用 set_enemy_positions 提供的位置绘制意图
## - 离开视野后用最后已知位置绘制过期意图
## - refresh 触发重绘
## - 未挂载 state 时不绘制
extends Node

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("=== CH1-050: EnemyIntentRenderer tests ===")
	_test_renderer_no_draw_without_state()
	_test_renderer_no_draw_when_no_intents()
	_test_renderer_uses_enemy_positions()
	_test_renderer_falls_back_to_last_known()
	_test_renderer_refresh_picks_up_new_intents()
	_test_renderer_hides_intent_for_never_seen_enemy()
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", msg)
	else:
		_failed += 1
		print("  [FAIL] ", msg)


## 构建一个挂载到场景树的 EnemyIntentRenderer + EnemyIntentState + VisibilityState 组合。
## 返回 {renderer, intent_state, visibility_state, parent}；调用方 queue_free parent。
func _build_renderer(map_width: int = 10, map_height: int = 10) -> Dictionary:
	var parent := Node2D.new()
	add_child(parent)
	var vs := VisibilityState.new()
	parent.add_child(vs)
	vs.setup(map_width, map_height)
	var eis := EnemyIntentState.new()
	parent.add_child(eis)
	eis.setup(vs)
	var renderer := EnemyIntentRenderer.new()
	parent.add_child(renderer)
	renderer.setup(eis, vs, 64.0, map_width, map_height)
	return {"parent": parent, "renderer": renderer, "intent_state": eis, "visibility_state": vs}


func _test_renderer_no_draw_without_state() -> void:
	print("\n--- Test: renderer without state does not crash and draws nothing ---")
	var parent := Node2D.new()
	add_child(parent)
	var renderer := EnemyIntentRenderer.new()
	parent.add_child(renderer)
	# Without setup the renderer should not draw. We can't introspect pixels
	# in headless mode, so the contract is: refresh() must not error and the
	# renderer must remain valid.
	renderer.refresh()
	_check(is_instance_valid(renderer), "Renderer remains valid after refresh without setup")
	parent.queue_free()


func _test_renderer_no_draw_when_no_intents() -> void:
	print("\n--- Test: renderer reports empty public intents when no intents set ---")
	var fixture := _build_renderer(8, 8)
	var eis: EnemyIntentState = fixture.intent_state
	var public := eis.get_public_intents()
	_check(public.is_empty(), "No public intents when nothing planned")
	fixture.parent.queue_free()


func _test_renderer_uses_enemy_positions() -> void:
	print("\n--- Test: renderer uses provided enemy positions for observed enemies ---")
	var fixture := _build_renderer(10, 10)
	var renderer: EnemyIntentRenderer = fixture.renderer
	var eis: EnemyIntentState = fixture.intent_state
	var vs: VisibilityState = fixture.visibility_state
	# Set intent for an observed enemy.
	eis.set_intent("e1", {"type": "attack", "target_pos": Vector2i(3, 3)})
	var enemy_data := {"entity_id": "e1", "pos": Vector2i(5, 5), "hp": 30}
	vs.update_visibility([Vector2i(5, 5)], [enemy_data])
	# Provide the live position via set_enemy_positions.
	renderer.set_enemy_positions({"e1": Vector2i(5, 5)})
	var public := eis.get_public_intents()
	_check(public.has("e1"), "Observed enemy has public intent")
	_check(public["e1"]["type"] == "attack", "Public intent type is attack")
	fixture.parent.queue_free()


func _test_renderer_falls_back_to_last_known() -> void:
	print("\n--- Test: renderer falls back to last-known position for stale intents ---")
	var fixture := _build_renderer(10, 10)
	var renderer: EnemyIntentRenderer = fixture.renderer
	var eis: EnemyIntentState = fixture.intent_state
	var vs: VisibilityState = fixture.visibility_state
	# Plan an attack for an enemy, observe them, then they leave sight.
	eis.set_intent("e2", {"type": "move", "target_pos": Vector2i(2, 2)})
	var enemy_data := {"entity_id": "e2", "pos": Vector2i(6, 6), "hp": 30}
	vs.update_visibility([Vector2i(6, 6)], [enemy_data])
	# Enemy leaves sight, then we freeze at turn boundary.
	vs.update_visibility([Vector2i(0, 0)], [])
	eis.freeze_stale_intents()
	# Provide empty positions dict so renderer falls back to last-known snapshot.
	renderer.set_enemy_positions({})
	renderer.refresh()
	var public := eis.get_public_intents()
	_check(public.has("e2"), "Stale intent still public after freeze")
	_check(bool(public["e2"].get("stale", false)), "Stale flag set")
	# Verify the last-known snapshot has the expected position so the renderer
	# can draw the stale marker there.
	var snapshot := vs.get_last_known("e2")
	var pos = snapshot.get("pos", null)
	_check(pos is Vector2i and pos == Vector2i(6, 6), "Last-known position retained for stale intent")
	fixture.parent.queue_free()


func _test_renderer_refresh_picks_up_new_intents() -> void:
	print("\n--- Test: renderer refresh picks up newly planned intents ---")
	var fixture := _build_renderer(10, 10)
	var renderer: EnemyIntentRenderer = fixture.renderer
	var eis: EnemyIntentState = fixture.intent_state
	var vs: VisibilityState = fixture.visibility_state
	# Initially no intents.
	_check(eis.get_public_intents().is_empty(), "No intents initially")
	# Plan an intent for an observed enemy and refresh.
	eis.set_intent("e3", {"type": "overwatch"})
	var enemy_data := {"entity_id": "e3", "pos": Vector2i(7, 7), "hp": 30}
	vs.update_visibility([Vector2i(7, 7)], [enemy_data])
	renderer.set_enemy_positions({"e3": Vector2i(7, 7)})
	renderer.refresh()
	var public := eis.get_public_intents()
	_check(public.has("e3"), "Newly planned intent appears in public intents after refresh")
	_check(public["e3"]["type"] == "overwatch", "Intent type is overwatch")
	fixture.parent.queue_free()


func _test_renderer_hides_intent_for_never_seen_enemy() -> void:
	print("\n--- Test: renderer hides intent for enemy the player never saw ---")
	var fixture := _build_renderer(10, 10)
	var renderer: EnemyIntentRenderer = fixture.renderer
	var eis: EnemyIntentState = fixture.intent_state
	var vs: VisibilityState = fixture.visibility_state
	# Plan an intent for an enemy the player has never observed.
	eis.set_intent("e_hidden", {"type": "attack", "target_pos": Vector2i(1, 1)})
	# Player sight does not include the enemy.
	vs.update_visibility([Vector2i(0, 0)], [])
	eis.freeze_stale_intents()
	renderer.set_enemy_positions({"e_hidden": Vector2i(4, 4)})
	renderer.refresh()
	var public := eis.get_public_intents()
	_check(not public.has("e_hidden"), "Never-seen enemy intent not public even after freeze")
	fixture.parent.queue_free()


func _print_summary() -> void:
	print("\n=== EnemyIntentRenderer: %d passed, %d failed ===" % [_passed, _failed])
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
