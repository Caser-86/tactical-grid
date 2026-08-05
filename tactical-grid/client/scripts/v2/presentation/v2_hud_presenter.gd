extends RefCounted
class_name V2HudPresenter

## V2 HUD 表现层。
## 战斗控制器只提交状态快照，具体排版由 HUD 负责，避免玩法逻辑直接改多个标签。

var _hud: Node = null
var last_snapshot: Dictionary = {}

func setup(hud: Node) -> void:
	_hud = hud
	if not last_snapshot.is_empty():
		render(last_snapshot)

func render(snapshot: Dictionary) -> void:
	last_snapshot = snapshot.duplicate(true)
	if _hud == null or not is_instance_valid(_hud):
		return
	_hud.call("render_v2_snapshot", last_snapshot)
