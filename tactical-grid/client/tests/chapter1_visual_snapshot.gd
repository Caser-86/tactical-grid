## CH1-090 visual QA helper.
## Renders the first battle scene at a requested resolution and accessibility mode,
## then writes one PNG for visual review. Use qa-mode=grayscale for a luminance
## check; this scene is excluded from release export.
extends Node

const BattleScene = preload("res://scenes/battle.tscn")

var target_size := Vector2i(1280, 720)
var colorblind_mode := "none"
var output_path := "build/chapter1_visual_1280x720_none.png"

func _ready() -> void:
	_parse_user_args()
	get_window().size = target_size
	get_viewport().size = target_size

	GameManager.current_level_id = "ch1_m1"
	GameManager.current_save = SaveManager.create_default_save()
	GameManager.current_save["characters"] = GameManager.progression.create_starter_roster()
	var settings: Dictionary = GameManager.current_save.get("settings", {}).duplicate(true)
	settings["colorblind_mode"] = colorblind_mode
	GameManager.current_save["settings"] = settings
	AccessibilitySettings.apply_settings(settings)

	var battle := BattleScene.instantiate() as BattleController
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Skip blocking intro/tutorial panels for a clean battlefield composition shot.
	if GameManager._active_dialogue and is_instance_valid(GameManager._active_dialogue):
		GameManager._active_dialogue._end_dialogue()
	if battle._active_tutorial_hint and is_instance_valid(battle._active_tutorial_hint):
		battle._active_tutorial_hint._on_continue()
	await get_tree().process_frame
	if battle.turn_manager == null:
		battle._start_battle()
	battle._dismiss_context_hint()
	await get_tree().process_frame
	await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Visual snapshot failed: viewport image is empty")
		get_tree().quit(1)
		return
	if colorblind_mode == "grayscale":
		_apply_grayscale(image)
	var absolute_path := output_path
	if not absolute_path.is_absolute_path():
		absolute_path = ProjectSettings.globalize_path(absolute_path)
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("Visual snapshot failed to save: %s (%s)" % [absolute_path, error])
		get_tree().quit(1)
		return
	print("Visual snapshot saved: %s (%dx%d, mode=%s)" % [absolute_path, image.get_width(), image.get_height(), colorblind_mode])
	get_tree().quit(0)

func _parse_user_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-size="):
			var parts := argument.trim_prefix("--qa-size=").split("x")
			if parts.size() == 2:
				target_size = Vector2i(maxi(640, int(parts[0])), maxi(360, int(parts[1])))
		elif argument.begins_with("--qa-mode="):
			colorblind_mode = argument.trim_prefix("--qa-mode=")
		elif argument.begins_with("--qa-output="):
			output_path = argument.trim_prefix("--qa-output=")

func _apply_grayscale(image: Image) -> void:
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			image.set_pixel(x, y, Color(luminance, luminance, luminance, color.a))
