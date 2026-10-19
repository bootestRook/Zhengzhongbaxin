class_name CoreEffectInstance
extends RefCounted

var instance_id: String = ""
var effect_id: String = ""
var source_entity_id: String = ""
var target_entity_id: String = ""
var applied_tick: int = 0
var next_period_tick: int = -1
var expires_tick: int = -1
var stacks: int = 1
var grant_handles: Array[String] = []
var modifier_handles: Array[String] = []
var lifecycle: String = "active"


func is_expired(current_tick: int) -> bool:
	return lifecycle == "active" and expires_tick >= 0 and current_tick >= expires_tick


func is_period_due(current_tick: int) -> bool:
	return lifecycle == "active" and next_period_tick >= 0 and current_tick >= next_period_tick


func snapshot() -> Dictionary:
	return {
		"instance_id": instance_id,
		"effect_id": effect_id,
		"source_entity_id": source_entity_id,
		"target_entity_id": target_entity_id,
		"applied_tick": applied_tick,
		"next_period_tick": next_period_tick,
		"expires_tick": expires_tick,
		"stacks": stacks,
		"grant_handles": grant_handles.duplicate(),
		"modifier_handles": modifier_handles.duplicate(),
		"lifecycle": lifecycle,
	}
