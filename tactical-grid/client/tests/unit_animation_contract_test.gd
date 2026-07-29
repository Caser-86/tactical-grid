extends Node

const REQUIRED_STATES: Array[StringName] = [
	&"idle", &"move", &"attack", &"hit", &"skill", &"death",
]

var _passed := 0
var _failed := 0
var _errors: Array[String] = []
var _units: Array[Unit] = []
var _observed_camera_event: StringName = &""

func _ready() -> void:
	print("=== Unit animation contract test ===")
	await _test_runtime_art_and_states()
	await _test_camera_event_feedback()
	await _cleanup()
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)

func _test_runtime_art_and_states() -> void:
	var assault := _create_unit("assault", "Assault")
	var heavy := _create_unit("heavy", "Heavy")
	var drone := GameData.create_enemy_unit("drone_assault")
	_units.append(drone)
	var boss := GameData.create_enemy_unit("sentry_elite")
	boss.unit_name = "Data Sentinel"
	boss.boss_art_key = &"boss_data_sentinel"
	boss.max_shield = 50
	boss.current_shield = 50
	_units.append(boss)

	var assault_view := await _create_view(assault)
	var heavy_view := await _create_view(heavy)
	var drone_view := await _create_view(drone)
	var boss_view := await _create_view(boss)

	for entry in [
		[assault_view, &"assault"],
		[heavy_view, &"heavy"],
		[drone_view, &"drone_assault"],
	]:
		var view: UnitSprite = entry[0]
		var art := view.get_node_or_null("Art")
		_check(art is Sprite2D and art.texture is Texture2D, "%s uses a runtime art texture" % entry[1])

	var boss_art := boss_view.get_node_or_null("Art") as Sprite2D
	_check(boss_art != null and boss_art.texture is Texture2D, "boss uses its dedicated runtime art texture")
	if boss_art and boss_art.texture:
		var boss_texture_size := boss_art.texture.get_size()
		var boss_render_size := maxf(boss_texture_size.x, boss_texture_size.y) * boss_art.scale.x
		_check(boss_render_size >= 72.0, "boss art renders larger than standard units")
	_check(boss_view.has_method("has_visible_shield_bar") and boss_view.has_visible_shield_bar(), "shielded boss exposes a visible shield bar")

	var textures := [
		ArtCatalog.get_texture(&"unit", &"assault"),
		ArtCatalog.get_texture(&"unit", &"heavy"),
		ArtCatalog.get_texture(&"unit", &"drone_assault"),
	]
	_check(textures.all(func(texture): return texture is Texture2D), "sample textures load through ArtCatalog")
	if textures.all(func(texture): return texture is Texture2D):
		_check(_alpha_mask_difference(textures[0], textures[1]) >= 0.10, "assault and heavy silhouettes differ")
		_check(_alpha_mask_difference(textures[0], textures[2]) >= 0.10, "assault and drone silhouettes differ")
		_check(_alpha_mask_difference(textures[1], textures[2]) >= 0.10, "heavy and drone silhouettes differ")

	_check(assault_view.has_method("get_supported_states"), "UnitSprite exposes supported visual states")
	if assault_view.has_method("get_supported_states"):
		var supported: Array = assault_view.get_supported_states()
		for state in REQUIRED_STATES:
			_check(state in supported, "UnitSprite supports %s state" % state)

	_check(assault_view.has_method("play_state"), "UnitSprite exposes state playback")
	if assault_view.has_method("play_state") and assault_view.has_method("get_current_state"):
		assault_view.play_state(&"attack", Vector2.RIGHT, 0.08)
		_check(assault_view.get_current_state() == &"attack", "attack state starts immediately")
		await get_tree().create_timer(0.14).timeout
		_check(assault_view.get_current_state() == &"idle", "attack state returns to idle")

		assault_view.play_state(&"hit", Vector2.LEFT, 0.08)
		_check(assault_view.get_current_state() == &"hit", "hit state starts immediately")
		await get_tree().create_timer(0.14).timeout
		_check(assault_view.get_current_state() == &"idle", "hit state returns to idle")

	_check(heavy_view.has_method("play_move_to"), "UnitSprite exposes interpolated movement")
	if heavy_view.has_method("play_move_to") and heavy_view.has_method("get_current_state"):
		heavy_view.position = Vector2.ZERO
		heavy_view.play_move_to(Vector2(64, 0), 0.08)
		_check(heavy_view.get_current_state() == &"move", "move state starts immediately")
		await get_tree().create_timer(0.14).timeout
		_check(heavy_view.position.is_equal_approx(Vector2(64, 0)), "move reaches the target position")
		_check(heavy_view.get_current_state() == &"idle", "move state returns to idle")

	_check(drone_view.has_method("play_death"), "UnitSprite exposes death playback")
	if drone_view.has_method("play_death") and drone_view.has_method("get_current_state"):
		drone_view.play_death(0.08)
		await get_tree().create_timer(0.12).timeout
		_check(drone_view.get_current_state() == &"death", "death state remains terminal")

func _test_camera_event_feedback() -> void:
	var camera := BattleCameraController.new()
	add_child(camera)
	camera.setup(Rect2(Vector2.ZERO, Vector2(896, 640)), Rect2(Vector2.ZERO, Vector2(640, 480)))
	_check(camera.has_method("play_event_feedback"), "battle camera exposes event-driven feedback")
	if not camera.has_method("play_event_feedback"):
		return
	_observed_camera_event = &""
	camera.event_feedback_started.connect(_on_camera_event_feedback)
	var origin := camera.position
	camera.play_event_feedback(&"critical", Vector2(448, 320), 0.08)
	_check(_observed_camera_event == &"critical", "critical feedback emits a typed event")
	await get_tree().create_timer(0.14).timeout
	_check(camera.position.distance_to(origin) <= 0.5, "camera feedback returns to its stable position")

func _on_camera_event_feedback(kind: StringName) -> void:
	_observed_camera_event = kind

func _create_unit(job: String, unit_name: String) -> Unit:
	var unit := GameData.create_player_unit(job, unit_name)
	_units.append(unit)
	return unit

func _create_view(unit: Unit) -> UnitSprite:
	var view := UnitSprite.new()
	add_child(view)
	view.update_unit(unit)
	await get_tree().process_frame
	return view

func _alpha_mask_difference(first: Texture2D, second: Texture2D) -> float:
	var image_a := first.get_image()
	var image_b := second.get_image()
	if image_a == null or image_b == null or image_a.get_size() != image_b.get_size():
		return 1.0
	var changed := 0
	var union_count := 0
	for y in range(image_a.get_height()):
		for x in range(image_a.get_width()):
			var alpha_a := image_a.get_pixel(x, y).a >= 0.15
			var alpha_b := image_b.get_pixel(x, y).a >= 0.15
			if alpha_a or alpha_b:
				union_count += 1
				if alpha_a != alpha_b:
					changed += 1
	return float(changed) / float(maxi(1, union_count))

func _cleanup() -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	for unit in _units:
		if is_instance_valid(unit):
			unit.free()
	_units.clear()

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", message)
	else:
		_failed += 1
		_errors.append(message)
		print("  [FAIL] ", message)

func _print_summary() -> void:
	print("\n=== Test summary ===")
	print("  Passed: %d" % _passed)
	print("  Failed: %d" % _failed)
	for error in _errors:
		print("    - ", error)
