## 角色详情面板运行时视觉快照。
## 用于确认职业纹理实际渲染到基地面板，而不是只通过资源契约。
extends Node

const CharacterPanelScene = preload("res://scenes/character_panel.tscn")

var target_size := Vector2i(1280, 720)
var output_path := "build/character_panel_visual_1280x720.png"

func _ready() -> void:
	_parse_user_args()
	get_window().size = target_size
	get_viewport().size = target_size

	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	GameManager.begin_new_game_for_test(0)

	var panel := CharacterPanelScene.instantiate() as CharacterPanel
	add_child(panel)
	await get_tree().process_frame
	panel.open_panel(0)
	await get_tree().process_frame
	await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Character panel visual snapshot failed: viewport image is empty")
		get_tree().quit(1)
		return
	var absolute_path := output_path
	if not absolute_path.is_absolute_path():
		absolute_path = ProjectSettings.globalize_path(absolute_path)
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("Character panel visual snapshot failed to save: %s (%s)" % [absolute_path, error])
		get_tree().quit(1)
		return
	print("Character panel visual snapshot saved: %s (%dx%d)" % [absolute_path, image.get_width(), image.get_height()])

	panel.free()
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	get_tree().quit(0)

func _parse_user_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-size="):
			var parts := argument.trim_prefix("--qa-size=").split("x")
			if parts.size() == 2:
				target_size = Vector2i(maxi(640, int(parts[0])), maxi(360, int(parts[1])))
		elif argument.begins_with("--qa-output="):
			output_path = argument.trim_prefix("--qa-output=")
