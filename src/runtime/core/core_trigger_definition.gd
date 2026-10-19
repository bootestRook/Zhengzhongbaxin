class_name CoreTriggerDefinition
extends RefCounted

var trigger_id: String = ""
var event_type: String = ""
var condition_id: String = ""
var action_id: String = ""
var scope: String = "target"
var priority: int = 0
var max_triggers: int = -1
var cooldown_ticks: int = 0
var excluded_cause_tags: Array[String] = []


func _init(
	definition_trigger_id: String = "",
	definition_event_type: String = "",
	definition_condition_id: String = "",
	definition_action_id: String = ""
) -> void:
	trigger_id = definition_trigger_id
	event_type = definition_event_type
	condition_id = definition_condition_id
	action_id = definition_action_id


func validate() -> String:
	if trigger_id.is_empty():
		return "trigger_id_empty"
	if event_type.is_empty():
		return "trigger_event_type_empty"
	if action_id.is_empty():
		return "trigger_action_id_empty"
	if not ["source", "target", "session"].has(scope):
		return "trigger_scope_invalid"
	if max_triggers == 0 or max_triggers < -1:
		return "trigger_max_triggers_invalid"
	if cooldown_ticks < 0:
		return "trigger_cooldown_invalid"
	return ""


func snapshot() -> Dictionary:
	return {
		"trigger_id": trigger_id,
		"event_type": event_type,
		"condition_id": condition_id,
		"action_id": action_id,
		"scope": scope,
		"priority": priority,
		"max_triggers": max_triggers,
		"cooldown_ticks": cooldown_ticks,
		"excluded_cause_tags": excluded_cause_tags.duplicate(),
	}
