extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")

const REQUIRED_SEMANTIC_CUES: Array[StringName] = [
	&"assault_shot",
	&"scout_shot",
	&"sentry_shot",
	&"drone_scan",
	&"shield_protect",
	&"hit",
	&"shield_absorb",
	&"downed",
	&"objective_update",
	&"rescue",
	&"evac",
]

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
	t.check(audio.has_method("has_semantic_sfx"), "AudioManager 暴露语义音效可用性查询")
	t.check(audio.has_method("get_semantic_sfx_id"), "AudioManager 暴露语义音效映射查询")
	t.check(audio.has_method("play_semantic_sfx"), "AudioManager 暴露语义音效播放入口")
	if audio.has_method("has_semantic_sfx"):
		for cue_id in REQUIRED_SEMANTIC_CUES:
			t.check(audio.has_semantic_sfx(cue_id), "语义音效已注册且资源存在: %s" % cue_id)
	if audio.has_method("get_semantic_sfx_id"):
		t.check(audio.get_semantic_sfx_id(&"assault_shot") == &"sfx_combat_smg", "突击兵射击复用合法 SMG 音效")
		t.check(audio.get_semantic_sfx_id(&"sentry_shot") == &"sfx_combat_sniper", "哨戒兵射击复用合法狙击音效")
		t.check(audio.get_semantic_sfx_id(&"drone_scan") == &"sfx_network_scan", "无人机扫描复用合法网络扫描音效")
	t.finish(self)
