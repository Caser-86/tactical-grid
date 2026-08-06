extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const VisualModeScript = preload("res://scripts/v2/presentation/v2_visual_mode.gd")
const InputBindingsScript = preload("res://scripts/game/input_bindings.gd")

var t := Runner.new()

func _initialize() -> void:
	var defaults := VisualModeScript.default_settings()
	t.check(defaults["ui_scale"] == 1.0, "V2 默认文字缩放为 100%")
	t.check(defaults["visual_mode"] == "normal", "V2 默认视觉模式为普通")
	t.check(defaults["fullscreen"] == false and defaults["resolution"] == "1280x720", "V2 默认窗口设置明确")
	t.check(defaults["master_volume"] == 1.0 and defaults["music_volume"] == 1.0 and defaults["sfx_volume"] == 1.0, "V2 默认音量设置完整")
	t.check(defaults["reduce_motion"] == false and defaults["screen_shake"] == true, "V2 默认动态效果设置明确")

	var normalized := VisualModeScript.normalize({
		"ui_scale": 1.4,
		"visual_mode": "not_a_mode",
		"large_text": true,
		"colorblind_mode": "deuteranopia",
	})
	t.check(is_equal_approx(float(normalized["ui_scale"]), 1.5), "V2 非法缩放值归一化到最近档位")
	t.check(normalized["visual_mode"] == "normal", "V2 非法视觉模式回退为普通")

	var migrated_text := VisualModeScript.normalize({"large_text": true})
	var migrated_color := VisualModeScript.normalize({"colorblind_mode": "deuteranopia"})
	t.check(is_equal_approx(float(migrated_text["ui_scale"]), 1.25), "V2 兼容旧档大字体设置")
	t.check(migrated_color["visual_mode"] == "deuteranopia_assist", "V2 兼容旧档色弱设置")

	var applied := VisualModeScript.apply({"ui_scale": 1.5, "visual_mode": "grayscale"})
	t.check(is_equal_approx(VisualModeScript.current_ui_scale(), 1.5), "V2 应用设置后缩放状态可读取")
	t.check(VisualModeScript.current_mode() == &"grayscale", "V2 应用设置后视觉模式可读取")
	t.check(applied["visual_mode"] == "grayscale", "V2 应用设置返回归一化结果")
	t.check(VisualModeScript.UI_SCALES == [1.0, 1.25, 1.5], "V2 只暴露三档文字缩放")
	t.check(VisualModeScript.VISUAL_MODES == [&"normal", &"grayscale", &"deuteranopia_assist"], "V2 只暴露三种视觉模式")

	var bindings := InputBindingsScript.new()
	var binding_settings := {"keybindings": {}}
	bindings.ensure_settings(binding_settings)
	t.check(InputBindingsScript.V2_ACTIONS == ["pause", "end_turn", "next_unit", "focus_unit", "toggle_network"], "V2 键位说明只包含五个核心动作")
	t.check(binding_settings["keybindings"].has("focus_unit"), "V2 默认键位包含聚焦单位")
	t.check(InputMap.has_action("focus_unit"), "V2 工程输入映射包含聚焦单位")
	var pause_binding: Dictionary = binding_settings["keybindings"]["pause"]
	t.check(bindings.find_conflict("focus_unit", pause_binding, InputBindingsScript.V2_ACTIONS) == "pause", "V2 键位冲突能指出占用动作")

	bindings.free()
	t.finish(self)
