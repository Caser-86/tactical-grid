## CH1-050: Enemy intent visualization layer.
## Draws observed enemy intents (attack arrows, move targets, overwatch cones,
## lethal/suppressed/stale markers) on top of the unit layer so the player can
## read the most dangerous known threats before ending the turn.
## Information comes from EnemyIntentState.get_public_intents(), which already
## filters by visibility and suppresses lethal intents for newly revealed
## enemies. The renderer never reads raw AI state.
extends Node2D
class_name EnemyIntentRenderer

## Attack intent arrow color (red). Lethal attacks use the brighter variant.
const COLOR_ATTACK := Color(0.95, 0.28, 0.22, 0.78)
const COLOR_ATTACK_LETHAL := Color(1.0, 0.42, 0.32, 0.95)
## Move intent arrow color (amber dashed).
const COLOR_MOVE := Color(0.96, 0.74, 0.22, 0.72)
## Overwatch cone color (cyan translucent).
const COLOR_OVERWATCH := Color(0.20, 0.78, 0.92, 0.22)
const COLOR_OVERWATCH_EDGE := Color(0.28, 0.86, 1.0, 0.62)
## Stale intent color (grey, dimmed).
const COLOR_STALE := Color(0.55, 0.58, 0.62, 0.50)
## Suppressed lethal color (blue tint, "unknown" marker).
const COLOR_SUPPRESSED := Color(0.42, 0.62, 0.96, 0.72)

## Arrow head size in pixels.
const ARROW_HEAD_SIZE := 9.0
## Overwatch cone radius in cells.
const OVERWATCH_CONE_RADIUS := 5
## Overwatch cone half-angle in degrees.
const OVERWATCH_CONE_HALF_ANGLE := 35.0

var _intent_state: EnemyIntentState = null
var _visibility_state: VisibilityState = null
## entity_id -> Vector2i (current render position of each enemy).
## Provided by BattleController when it refreshes the renderer so we can draw
## arrows from the enemy's on-map position even when only a last-known
## snapshot is available.
var _enemy_positions: Dictionary = {}
var _cell_size: float = 64.0
var _map_width: int = 0
var _map_height: int = 0


## Bind to the battle state. Cell size and map dimensions match the battle grid.
func setup(
	intent_state: EnemyIntentState,
	visibility_state: VisibilityState,
	cell_size: float,
	map_width: int,
	map_height: int,
) -> void:
	_intent_state = intent_state
	_visibility_state = visibility_state
	_cell_size = maxf(8.0, cell_size)
	_map_width = maxi(0, map_width)
	_map_height = maxi(0, map_height)
	z_index = 95
	queue_redraw()


## Update the cached enemy positions. positions is entity_id -> Vector2i.
func set_enemy_positions(positions: Dictionary) -> void:
	_enemy_positions = positions.duplicate(true)
	queue_redraw()


## Re-render. Called by BattleController whenever intents or visibility change.
func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if _intent_state == null or _visibility_state == null:
		return
	if _map_width <= 0 or _map_height <= 0:
		return
	var public_intents: Dictionary = _intent_state.get_public_intents()
	for eid in public_intents.keys():
		var intent: Dictionary = public_intents[eid]
		var origin := _get_enemy_cell(eid)
		if origin.x < 0:
			continue
		_draw_single_intent(origin, intent)


## Resolve the cell to draw the intent from. Observed enemies use their live
## position; stale intents fall back to the last-known position snapshot.
func _get_enemy_cell(entity_id: String) -> Vector2i:
	if _enemy_positions.has(entity_id):
		var pos = _enemy_positions[entity_id]
		if pos is Vector2i and pos.x >= 0:
			return pos
	if _visibility_state == null:
		return Vector2i(-1, -1)
	var snapshot: Dictionary = _visibility_state.get_last_known(entity_id)
	var pos = snapshot.get("pos", null)
	if pos is Vector2i:
		return pos
	return Vector2i(-1, -1)


func _draw_single_intent(origin_cell: Vector2i, intent: Dictionary) -> void:
	var itype: String = String(intent.get("type", "wait"))
	var is_lethal: bool = bool(intent.get("lethal", false))
	var is_stale: bool = bool(intent.get("stale", false))
	var is_suppressed: bool = bool(intent.get("suppressed", false))
	var origin := _cell_to_world_center(origin_cell)

	# Stale intents are drawn dimmed so the player can tell the information
	# is outdated at a glance, without hiding it entirely.
	var stale_alpha := 1.0
	if is_stale:
		stale_alpha = 0.55

	match itype:
		"attack":
			var target_pos = intent.get("target_pos", null)
			if target_pos is Vector2i and target_pos.x >= 0:
				var target := _cell_to_world_center(target_pos)
				var color := COLOR_ATTACK if not is_lethal else COLOR_ATTACK_LETHAL
				if is_suppressed:
					color = COLOR_SUPPRESSED
				color.a *= stale_alpha
				_draw_attack_arrow(origin, target, color, is_lethal and not is_suppressed)
			# Lethal marker above the enemy even if target is missing.
			if is_lethal and not is_suppressed:
				_draw_lethal_marker(origin, stale_alpha)
		"move", "move_to_cover":
			var target_pos = intent.get("target_pos", null)
			if target_pos is Vector2i and target_pos.x >= 0:
				var target := _cell_to_world_center(target_pos)
				var color := COLOR_MOVE
				color.a *= stale_alpha
				_draw_dashed_arrow(origin, target, color)
		"overwatch":
			# Draw a small overwatch triangle marker above the enemy.
			var color := COLOR_OVERWATCH_EDGE
			color.a *= stale_alpha
			_draw_overwatch_marker(origin, color)
		"scan":
			var target_pos = intent.get("target_pos", null)
			if target_pos is Vector2i and target_pos.x >= 0:
				var target := _cell_to_world_center(target_pos)
				var color := COLOR_SUPPRESSED
				color.a *= stale_alpha
				_draw_dashed_arrow(origin, target, color)
		_:
			pass

	# Stale tag drawn below the enemy so the player can tell which intents
	# are outdated even when the type is the same.
	if is_stale:
		_draw_stale_tag(origin, stale_alpha)


func _cell_to_world_center(cell: Vector2i) -> Vector2:
	return Vector2(
		(float(cell.x) + 0.5) * _cell_size,
		(float(cell.y) + 0.5) * _cell_size,
	)


func _draw_attack_arrow(from: Vector2, to: Vector2, color: Color, lethal: bool) -> void:
	var direction := (to - from).normalized()
	if direction.length_squared() < 0.001:
		return
	var length := from.distance_to(to)
	# Shorten the arrow so the head sits just before the target center.
	var end := to - direction * (_cell_size * 0.30)
	var start := from + direction * (_cell_size * 0.30)
	# Shaft
	draw_line(start, end, color, 3.0 if lethal else 2.0)
	# Arrow head
	_draw_arrow_head(end, direction, color, ARROW_HEAD_SIZE + (2.0 if lethal else 0.0))
	# Lethal attacks also draw a ring on the target cell for emphasis.
	if lethal:
		draw_arc(to, _cell_size * 0.42, 0, TAU, 32, color, 2.0)


func _draw_dashed_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	var direction := (to - from).normalized()
	if direction.length_squared() < 0.001:
		return
	var length := from.distance_to(to)
	var start := from + direction * (_cell_size * 0.30)
	var end := to - direction * (_cell_size * 0.30)
	var dash := 8.0
	var gap := 6.0
	var traveled := 0.0
	var seg_end := end
	while traveled < length - _cell_size * 0.6:
		var seg_start := start + direction * traveled
		var seg_stop := start + direction * minf(traveled + dash, length - _cell_size * 0.6)
		draw_line(seg_start, seg_stop, color, 2.0)
		traveled += dash + gap
	_draw_arrow_head(end, direction, color, ARROW_HEAD_SIZE * 0.8)


func _draw_arrow_head(tip: Vector2, direction: Vector2, color: Color, size: float) -> void:
	var perp := Vector2(-direction.y, direction.x)
	var base := tip - direction * size
	var left := base + perp * (size * 0.5)
	var right := base - perp * (size * 0.5)
	var points := PackedVector2Array([tip, left, right])
	draw_colored_polygon(points, color)


func _draw_overwatch_marker(origin: Vector2, color: Color) -> void:
	# Small triangle pointing up (representing vigilance) above the enemy.
	var center := origin + Vector2(0, -_cell_size * 0.55)
	var size := _cell_size * 0.18
	var points := PackedVector2Array([
		center + Vector2(0, -size),
		center + Vector2(size, size * 0.6),
		center + Vector2(-size, size * 0.6),
	])
	draw_colored_polygon(points, color)
	# Outline for readability on bright terrain.
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0.05, 0.07, 0.10, 0.65), 1.0, true)


func _draw_lethal_marker(origin: Vector2, alpha: float) -> void:
	# "!" symbol drawn above the enemy to signal a lethal intent.
	var pos := origin + Vector2(0, -_cell_size * 0.78)
	var color := Color(1.0, 0.34, 0.20, 0.95 * alpha)
	# Exclamation bar
	draw_rect(Rect2(pos - Vector2(1.5, 7), Vector2(3, 9)), color, true)
	# Exclamation dot
	draw_circle(pos + Vector2(0, 7), 2.0, color)


func _draw_stale_tag(origin: Vector2, alpha: float) -> void:
	# Small "..." marker below the enemy indicating the intent is outdated.
	var pos := origin + Vector2(0, _cell_size * 0.55)
	var color := Color(0.65, 0.68, 0.72, 0.85 * alpha)
	for i in range(3):
		draw_circle(pos + Vector2((i - 1) * 4, 0), 1.6, color)
