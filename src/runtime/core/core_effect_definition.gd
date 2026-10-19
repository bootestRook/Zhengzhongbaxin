class_name CoreEffectDefinition
extends RefCounted

var effect_id: String = ""
var duration_ticks: int = -1
var period_ticks: int = 0
var granted_tags: Array[String] = []
var stacking_policy: String = "independent"
var stacking_key: String = ""
var max_stacks: int = 1
var modifiers: Array[Dictionary] = []
var executions: Array[Dictionary] = []


func _init(
	definition_effect_id: String = "",
	definition_duration_ticks: int = -1,
	definition_period_ticks: int = 0,
	definition_granted_tags: Array[String] = []
) -> void:
	effect_id = definition_effect_id
	duration_ticks = definition_duration_ticks
	period_ticks = definition_period_ticks
	granted_tags = definition_granted_tags.duplicate()
	stacking_key = definition_effect_id


func validate() -> String:
	if effect_id.is_empty():
		return "effect_id_empty"
	if duration_ticks == 0 or duration_ticks < -1:
		return "effect_duration_invalid"
	if period_ticks < 0:
		return "effect_period_invalid"
	if not ["reject", "refresh", "add_stack", "replace", "independent"].has(stacking_policy):
		return "effect_stacking_policy_invalid"
	if stacking_key.is_empty():
		return "effect_stacking_key_empty"
	if max_stacks < 1:
		return "effect_max_stacks_invalid"
	for modifier: Dictionary in modifiers:
		if String(modifier.get("attribute_id", "")).is_empty():
			return "effect_modifier_attribute_empty"
		if not ["base_add", "multiply", "final_add", "override"].has(String(modifier.get("operation", "final_add"))):
			return "effect_modifier_operation_invalid"
		var magnitude := float(modifier.get("magnitude", 0.0))
		if magnitude == INF or magnitude == -INF or magnitude != magnitude:
			return "effect_modifier_not_finite"
	return ""


func snapshot() -> Dictionary:
	return {
		"effect_id": effect_id,
		"duration_ticks": duration_ticks,
		"period_ticks": period_ticks,
		"granted_tags": granted_tags.duplicate(),
		"stacking_policy": stacking_policy,
		"stacking_key": stacking_key,
		"max_stacks": max_stacks,
		"modifiers": modifiers.duplicate(true),
		"executions": executions.duplicate(true),
	}
