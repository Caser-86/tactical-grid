extends RefCounted
class_name V2IntentPresenter

## Converts a V2 enemy intent into stable visual affordance data.
## This layer only describes the presentation. It does not create nodes or draw
## anything, so the same contract can be consumed by HUD, map overlays, and
## headless tests without changing combat rules.

static func build(intent: Dictionary) -> Dictionary:
	var intent_type := String(intent.get("type", "guard"))
	var target_cell := Vector2i(-1, -1)
	var raw_target_cell: Variant = intent.get("target_cell", Vector2i(-1, -1))
	if raw_target_cell is Vector2i:
		target_cell = raw_target_cell
	var target_id := String(intent.get("target_id", ""))
	var damage := int(intent.get("damage", 0))
	var shape := "guard"
	var color_role := "guard"
	var icon_key := "guard"
	var pulse := false

	match intent_type:
		"attack":
			shape = "arrow"
			color_role = "attack"
			icon_key = "crosshair"
		"telegraph":
			shape = "arrow"
			color_role = "telegraph"
			icon_key = "warning"
			pulse = true
		"move", "move_to_cover":
			shape = "arrow"
			color_role = "move"
			icon_key = "route"
		"scan":
			shape = "cone"
			color_role = "scan"
			icon_key = "scan"
			pulse = true
		"protect":
			shape = "link"
			color_role = "protect"
			icon_key = "shield"
			pulse = true
		"guard":
			shape = "guard"
			color_role = "guard"
			icon_key = "guard"
		_: 
			shape = "guard"
			color_role = "guard"
			icon_key = "guard"

	var line_cells: Array[Vector2i] = []
	var raw_path: Variant = intent.get("path", [])
	if raw_path is Array:
		for raw_cell in raw_path:
			if raw_cell is Vector2i:
				line_cells.append(raw_cell)
	if line_cells.is_empty() and intent_type in ["attack", "telegraph"] and target_cell.x >= 0:
		line_cells.append(target_cell)

	return {
		"shape": shape,
		"color_role": color_role,
		"line_cells": line_cells,
		"target_cell": target_cell,
		"target_id": target_id,
		"damage_text": "伤害 %d" % damage if damage > 0 and intent_type in ["attack", "telegraph"] else "",
		"icon_key": icon_key,
		"pulse": pulse,
	}
