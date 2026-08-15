extends RefCounted
class_name V2HudPresenter

const V2IntentPresenterScript = preload("res://scripts/v2/presentation/v2_intent_presenter.gd")

## V2 HUD 表现层。
## 战斗控制器只提交状态快照，具体排版由 HUD 负责，避免玩法逻辑直接改多个标签。

var _hud: Node = null
var last_snapshot: Dictionary = {}

func setup(hud: Node) -> void:
	_hud = hud
	if not last_snapshot.is_empty():
		render(last_snapshot)

func render(snapshot: Dictionary) -> void:
	var normalized_snapshot: Dictionary = snapshot.duplicate(true)
	var raw_intents: Variant = normalized_snapshot.get("enemy_intents", {})
	if raw_intents is Dictionary:
		var normalized_intents: Dictionary = {}
		for entity_id in raw_intents.keys():
			var raw_intent: Variant = raw_intents[entity_id]
			if raw_intent is Dictionary:
				var intent: Dictionary = raw_intent.duplicate(true)
				intent["presentation"] = V2IntentPresenterScript.build(intent)
				normalized_intents[entity_id] = intent
		normalized_snapshot["enemy_intents"] = normalized_intents
	last_snapshot = normalized_snapshot
	if _hud == null or not is_instance_valid(_hud):
		return
	_hud.call("render_v2_snapshot", last_snapshot)
	var hint: Variant = last_snapshot.get("tutorial_hint", {})
	_hud.call("render_v2_tutorial_hint", hint if hint is Dictionary else {})
