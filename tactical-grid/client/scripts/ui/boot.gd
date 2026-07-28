## 启动场景
## 负责数据校验、设置加载、存档迁移和错误转场
extends Control

@onready var status_label: Label = $CenterContainer/StatusLabel
@onready var progress_bar: ProgressBar = $CenterContainer/ProgressBar

func _ready() -> void:
	GameManager.current_state = GameManager.GameState.BOOT
	_show_status("正在初始化...")
	await _run_boot_sequence()

func _show_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _set_progress(value: float) -> void:
	if progress_bar:
		progress_bar.value = value

func _run_boot_sequence() -> void:
	await _step_validate_data()
	await _step_load_settings()
	await _step_migrate_saves()
	await _step_wait_minimum()

	_show_status("启动完成")
	_set_progress(1.0)
	await get_tree().create_timer(0.2).timeout

	GameManager.go_to_main_menu()

func _step_validate_data() -> void:
	_show_status("加载游戏数据...")
	_set_progress(0.2)
	await get_tree().create_timer(0.05).timeout

	if GameData.has_errors():
		var errors = GameData.get_load_errors()
		push_error("Data load errors: " + ", ".join(errors))
		_show_status("数据加载失败，请检查安装")
		await get_tree().create_timer(2.0).timeout
		# 仍可进入主菜单，但功能受限

func _step_load_settings() -> void:
	_show_status("加载设置...")
	_set_progress(0.5)
	await get_tree().create_timer(0.05).timeout

	var settings = GameManager.get_settings()
	_apply_settings(settings)

func _apply_settings(settings: Dictionary) -> void:
	# 分辨率
	var resolution = settings.get("resolution", "1280x720")
	var parts = resolution.split("x")
	if parts.size() == 2:
		var width = int(parts[0])
		var height = int(parts[1])
		DisplayServer.window_set_size(Vector2i(width, height))

	# 全屏
	var fullscreen = settings.get("fullscreen", false)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# 音量
	AudioServer.set_bus_volume_db(0, linear_to_db(settings.get("master_volume", 1.0)))
	# TODO: 建立 Music/SFX bus 后分别设置

func _step_migrate_saves() -> void:
	_show_status("检查存档...")
	_set_progress(0.8)
	await get_tree().create_timer(0.05).timeout

	# SaveManager 加载时会自动尝试迁移和备份恢复
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.load_game(slot)

func _step_wait_minimum() -> void:
	_show_status("准备就绪...")
	_set_progress(0.95)
	await get_tree().create_timer(0.2).timeout
