## 保存、恢复并显示玩家可修改的菜单与战斗快捷键。
extends Node

const ACTIONS := ["pause", "end_turn", "next_unit", "toggle_grid"]
const DEFAULT_BINDINGS := {
	"pause": {"keycode": 0, "physical_keycode": 4194305},
	"end_turn": {"keycode": 0, "physical_keycode": 32},
	"next_unit": {"keycode": 0, "physical_keycode": 4194306},
	"toggle_grid": {"keycode": 0, "physical_keycode": 71},
}

func ensure_settings(settings: Dictionary) -> void:
	var bindings: Dictionary = settings.get("keybindings", {}).duplicate(true)
	for action in ACTIONS:
		if not bindings.has(action):
			bindings[action] = DEFAULT_BINDINGS[action].duplicate(true)
	settings["keybindings"] = bindings

func apply_settings(settings: Dictionary) -> void:
	ensure_settings(settings)
	var bindings: Dictionary = settings["keybindings"]
	for action in ACTIONS:
		_apply_binding(action, bindings[action])

func set_binding(action: String, binding: Dictionary) -> void:
	if not ACTIONS.has(action):
		return
	_apply_binding(action, binding)

func get_binding_data(action: String) -> Dictionary:
	if not InputMap.has_action(action):
		return {}
	var events := InputMap.action_get_events(action)
	if events.is_empty() or not events[0] is InputEventKey:
		return DEFAULT_BINDINGS.get(action, {}).duplicate(true)
	return _event_to_data(events[0] as InputEventKey)

func get_binding_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "未设置"
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "未设置"
	return events[0].as_text_physical_keycode()

func restore_defaults() -> Dictionary:
	var restored := DEFAULT_BINDINGS.duplicate(true)
	for action in ACTIONS:
		_apply_binding(action, restored[action])
	return restored

func _apply_binding(action: String, binding: Dictionary) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.keycode = int(binding.get("keycode", 0))
	event.physical_keycode = int(binding.get("physical_keycode", 0))
	InputMap.action_add_event(action, event)

func _event_to_data(event: InputEventKey) -> Dictionary:
	return {
		"keycode": event.keycode,
		"physical_keycode": event.physical_keycode,
	}
