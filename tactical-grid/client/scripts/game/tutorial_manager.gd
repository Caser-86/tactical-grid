extends Node

## 战斗内教学流程管理

signal step_changed(text: String)
signal tutorial_finished()

var _steps: Array[Dictionary] = []
var _current_index: int = -1
var _active: bool = false
var _flags: Array[String] = []

func start(flags: Array[String]) -> void:
	stop()
	_flags = flags.duplicate()
	_steps.clear()
	for flag in flags:
		match flag:
			"teach_movement":
				_steps.append({"id": "move", "text": "点击己方单位，再点击蓝色高亮格子进行移动。"})
			"teach_attack":
				_steps.append({"id": "attack", "text": "选中单位后点击攻击，再点击红色高亮范围内的敌人。"})
			"teach_cover":
				_steps.append({"id": "cover", "text": "靠近箱子或墙壁可获得掩体加成，敌人命中会降低。"})
			"teach_evac":
				_steps.append({"id": "evac", "text": "移动到绿色撤离点即可完成任务目标。"})
			"teach_overwatch":
				_steps.append({"id": "overwatch", "text": "警戒可以在敌人回合自动射击进入射程的目标。"})
			"teach_skills":
				_steps.append({"id": "skill", "text": "技能消耗 AP，有冷却时间，合理释放可扭转战局。"})
			"teach_items":
				_steps.append({"id": "item", "text": "物品可在战斗中恢复或辅助，注意携带数量。"})
			"teach_highground":
				_steps.append({"id": "highground", "text": "占据高地可获得命中和暴击加成。"})
			"teach_interaction":
				_steps.append({"id": "interact", "text": "靠近交互对象可使用技能或装置。"})

	if _steps.size() == 0:
		return
	_active = true
	_current_index = 0
	_emit_current()

func stop() -> void:
	_active = false
	_current_index = -1
	_steps.clear()
	_flags.clear()

func advance_if(step_id: String) -> void:
	if not _active:
		return
	if _current_index < 0 or _current_index >= _steps.size():
		return
	if _steps[_current_index].get("id", "") == step_id:
		_current_index += 1
		if _current_index >= _steps.size():
			tutorial_finished.emit()
			stop()
		else:
			_emit_current()

func current_text() -> String:
	if not _active or _current_index < 0 or _current_index >= _steps.size():
		return ""
	return _steps[_current_index].get("text", "")

func is_active() -> bool:
	return _active

func current_step_id() -> String:
	if not _active or _current_index < 0 or _current_index >= _steps.size():
		return ""
	return _steps[_current_index].get("id", "")

func has_flag(flag: String) -> bool:
	return flag in _flags

func _emit_current() -> void:
	step_changed.emit(current_text())
