extends RefCounted
class_name V2MissionEventBridge

## Converts an explicit evacuation checkpoint into a configured terminal event.
## The mission flow still owns readiness and idempotence; this seam only wires
## the real evacuation action to a data-defined final objective.
func apply_event(mission_flow: RefCounted, event_name: StringName, payload: Dictionary = {}) -> Dictionary:
	if mission_flow == null or not is_instance_valid(mission_flow):
		return {"success": false, "reason": &"v2_mission_flow_unavailable"}
	var result: Dictionary = mission_flow.apply_event(event_name, payload)
	if event_name != &"evac_checked" or not bool(result.get("success", false)):
		return result
	if bool(result.get("victory", false)) or not bool(result.get("changed", false)):
		return result
	if not mission_flow.has_method("get_current_step_complete_event"):
		return result
	var step_count := int(result.get("step_count", 0))
	var step_index := int(result.get("step_index", -1))
	var step_id := String(result.get("step_id", ""))
	if step_id.is_empty() or step_count <= 0 or step_index != step_count - 1:
		return result
	if StringName(mission_flow.get_current_step_complete_event()) != &"mission_completed":
		return result

	var final_result: Dictionary = mission_flow.apply_event(&"mission_completed", payload)
	final_result["bridge_source_event"] = event_name
	final_result["final_event_submitted"] = bool(final_result.get("success", false))
	final_result["evacuation_verified"] = true
	return final_result
