## 角色详情面板契约测试
## 验证基地角色面板展示真实职业纹理，而不是 ColorRect 占位块。
extends Node

const CharacterPanelScene = preload("res://scenes/character_panel.tscn")

var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []

func _ready() -> void:
	print("=== 角色详情面板契约测试 ===")
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	GameManager.begin_new_game_for_test(0)
	await get_tree().process_frame

	var panel := CharacterPanelScene.instantiate() as CharacterPanel
	add_child(panel)
	await get_tree().process_frame
	panel.open_panel(0)
	await get_tree().process_frame
	await get_tree().process_frame

	var portrait = panel.get_node_or_null("Panel/MainContainer/LeftContainer/Portrait")
	_check(portrait is TextureRect, "角色立绘节点使用 TextureRect 而不是颜色占位块")
	_check(portrait != null and portrait.texture is Texture2D, "首个突击兵加载真实角色纹理")
	if portrait is TextureRect and portrait.texture is Texture2D:
		_check(String(portrait.texture.resource_path).ends_with("assault_96.png"), "突击兵面板绑定 assault_96.png")
		_check(portrait.texture.get_width() > 0 and portrait.texture.get_height() > 0, "突击兵纹理尺寸有效")

	var roster := GameManager.get_roster()
	_check(roster.size() >= 5, "新游戏角色队伍包含五个职业")
	var expected_paths := {
		"assault": "assault_96.png",
		"sniper": "sniper_96.png",
		"heavy": "heavy_96.png",
		"medic": "medic_topdown_64.png",
		"scout": "scout_96.png",
	}
	for index in range(mini(5, roster.size())):
		panel.show_character(index)
		await get_tree().process_frame
		var character_portrait = panel.get_node_or_null("Panel/MainContainer/LeftContainer/Portrait")
		var job := String(roster[index].get("job", ""))
		_check(character_portrait is TextureRect and character_portrait.texture is Texture2D, "%s 职业面板有真实纹理" % job)
		if character_portrait is TextureRect and character_portrait.texture is Texture2D:
			_check(String(character_portrait.texture.resource_path).ends_with(String(expected_paths.get(job, ""))), "%s 绑定对应职业纹理" % job)

	panel.free()
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", message)
	else:
		_failed += 1
		_errors.append(message)
		print("  [FAIL] ", message)

func _print_summary() -> void:
	print("\n=== 测试总结 ===")
	print("  Passed: %d" % _passed)
	print("  Failed: %d" % _failed)
	if not _errors.is_empty():
		print("  Failures:")
		for error in _errors:
			print("    - ", error)
	print("  =================")
