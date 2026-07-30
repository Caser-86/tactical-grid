extends Node

func _ready() -> void:
	print("=== CODE-P0-04: 存档恢复测试 ===")
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	await get_tree().process_frame

	await _test_backup_recovery()
	await _test_future_version_refusal()
	await get_tree().process_frame
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	print("")
	print("通过: %d" % _passed)
	print("失败: %d" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)

var _passed := 0
var _failed := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", msg)
	else:
		_failed += 1
		print("  [FAIL] ", msg)

func _test_backup_recovery() -> void:
	print("\n--- 测试: 损坏主存档 + 有效 .bak 恢复 ---")
	var slot := 0
	# 1. 保存有效存档
	var save_data := SaveManager.create_default_save()
	save_data["playtime_seconds"] = 42
	_check(SaveManager.save_game(save_data, slot), "初始存档保存成功")

	# 2. 保存第二次（生成 .bak）
	save_data["playtime_seconds"] = 84
	_check(SaveManager.save_game(save_data, slot), "第二次保存成功")

	# 3. 验证 .bak 存在且包含 playtime=42
	var bak_path := "user://saves/save_%d.bak" % slot
	_check(FileAccess.file_exists(bak_path), ".bak 备份存在")
	var bak_text := FileAccess.open(bak_path, FileAccess.READ).get_as_text()
	_check(bak_text.contains("\"playtime_seconds\": 42"), ".bak 包含第一次存档数据")

	# 4. 损坏主存档
	var main_path := "user://saves/save_%d.json" % slot
	var f := FileAccess.open(main_path, FileAccess.WRITE)
	f.store_string("{CORRUPTED_JSON_DATA")
	f.close()

	# 5. 加载应从 .bak 恢复
	var loaded := SaveManager.load_game(slot)
	_check(not loaded.is_empty(), "损坏主存档从 .bak 恢复成功")
	_check(int(loaded.get("playtime_seconds", 0)) == 42, "恢复的存档是 .bak 中的有效数据")

	# 6. 验证 .bak 没有被损坏数据覆盖
	bak_text = FileAccess.open(bak_path, FileAccess.READ).get_as_text()
	_check(not bak_text.contains("CORRUPTED"), ".bak 未被损坏数据覆盖")

func _test_future_version_refusal() -> void:
	print("\n--- 测试: 未来版本存档拒绝 ---")
	var slot := 1
	# 直接写入一个未来版本的存档
	var future_data := SaveManager.create_default_save()
	future_data["save_version"] = "99.0.0"
	future_data["playtime_seconds"] = 100
	var json_str := JSON.stringify(future_data, "  ")
	var main_path := "user://saves/save_%d.json" % slot
	DirAccess.make_dir_recursive_absolute("user://saves/")
	var f := FileAccess.open(main_path, FileAccess.WRITE)
	f.store_string(json_str)
	f.close()

	# 加载应拒绝
	var loaded := SaveManager.load_game(slot)
	_check(loaded.is_empty(), "未来版本存档被拒绝加载")

	# 验证文件未被重写
	var current_text := FileAccess.open(main_path, FileAccess.READ).get_as_text()
	_check(current_text.contains("\"save_version\": \"99.0.0\""), "未来版本存档未被重写")

	SaveManager.delete_save(slot)
