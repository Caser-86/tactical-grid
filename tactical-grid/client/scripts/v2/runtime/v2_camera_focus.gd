extends RefCounted
class_name V2CameraFocus

## Resolve a player focus target without depending on the battle scene tree.
## Facility interactions may clear selection, but Home must remain useful.
static func resolve(selected_unit: Unit, player_units: Array) -> Unit:
	if selected_unit != null and is_instance_valid(selected_unit) and selected_unit.is_alive and selected_unit.team == "player":
		return selected_unit
	for raw_unit in player_units:
		if raw_unit is Unit and is_instance_valid(raw_unit):
			var unit: Unit = raw_unit
			if unit.is_alive and unit.team == "player":
				return unit
	return null
