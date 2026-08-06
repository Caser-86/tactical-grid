extends Control

@onready var status_label: Label = $CenterContainer/StatusLabel
@onready var progress_bar: ProgressBar = $CenterContainer/ProgressBar

func _ready() -> void:
	GameManager.current_state = GameManager.GameState.BOOT
	status_label.text = "正在启动渗透行动..."
	progress_bar.value = 0.3
	await get_tree().process_frame
	if not GameManager.v2_data_ready:
		status_label.text = "V2 数据不可用，请检查安装"
		return
	progress_bar.value = 0.75
	await get_tree().create_timer(0.15).timeout
	progress_bar.value = 1.0
	GameManager.go_to_main_menu()
