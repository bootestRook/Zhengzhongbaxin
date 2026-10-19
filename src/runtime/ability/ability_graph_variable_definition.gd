class_name AbilityGraphVariableDefinition
extends RefCounted

var variable_id: String = ""
var value_type: String = ""
var default_value: Variant = null
var save_behavior: String = "transient"


func _init(
	configured_id: String = "",
	configured_type: String = "",
	configured_default: Variant = null,
	configured_save_behavior: String = "transient"
) -> void:
	variable_id = configured_id
	value_type = configured_type
	default_value = configured_default
	save_behavior = configured_save_behavior


func validate() -> String:
	if variable_id.is_empty():
		return "graph_variable_id_empty"
	if value_type.is_empty():
		return "graph_variable_type_empty"
	if not ["transient", "save"].has(save_behavior):
		return "graph_variable_save_behavior_invalid"
	return ""


func to_dictionary() -> Dictionary:
	return {
		"variable_id": variable_id,
		"value_type": value_type,
		"default_value": default_value,
		"save_behavior": save_behavior,
	}
