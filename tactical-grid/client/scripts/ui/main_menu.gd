## 主菜单控制器
extends Control

@onready var continue_button = $VBoxContainer/ContinueButton
@onready var new_game_button = $VBoxContainer/NewGameButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready() -> void:
	continue_button.pressed.connect(_on_continue)
	new_game_button.pressed.connect(_on_new_game)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)

	# 检查是否有存档
	var has_save = _check_save()
	continue_button.disabled = not has_save

func _on_continue() -> void:
	# 加载最新存档
	get_tree().change_scene_to_file("res://scenes/base.tscn")

func _on_new_game() -> void:
	# 游客登录或显示登录界面
	get_tree().change_scene_to_file("res://scenes/base.tscn")

func _on_settings() -> void:
	# TODO: 打开设置界面
	pass

func _on_quit() -> void:
	get_tree().quit()

func _check_save() -> bool:
	# 检查本地是否有存档
	return false  # TODO: 实现存档检查
