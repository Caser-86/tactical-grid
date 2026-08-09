extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var t := Runner.new()
	t.check(DisplayServer.get_name() == "headless", "V2 音频无头契约仅在无头驱动验证")
	var audio := root.get_node_or_null("AudioManager")
	t.check(audio != null, "V2 音频无头契约找到 AudioManager")
	if audio == null:
		t.finish(self)
		return
	audio.stop_bgm()
	audio.stop_ambient()
	audio.audio_cache.clear()
	audio.play_bgm("bgm_battle_stealth")
	audio.play_ambient("ambient_industrial")
	audio.play_sfx("sfx_ui_click")
	t.check(audio.current_bgm == "", "无头运行不启动 BGM 播放")
	t.check(audio.audio_cache.is_empty(), "无头运行不加载音频资源")
	t.finish(self)
