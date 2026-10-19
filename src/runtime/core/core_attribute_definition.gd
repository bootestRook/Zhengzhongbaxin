class_name CoreAttributeDefinition
extends RefCounted

var attribute_id: String = ""
var default_value: float = 0.0
var minimum_value: float = -INF
var maximum_value: float = INF


func _init(
	definition_id: String = "",
	definition_default_value: float = 0.0,
	definition_minimum_value: float = -INF,
	definition_maximum_value: float = INF
) -> void:
	attribute_id = definition_id
	default_value = definition_default_value
	minimum_value = definition_minimum_value
	maximum_value = definition_maximum_value


func validate() -> String:
	if attribute_id.is_empty():
		return "attribute_id_empty"
	if minimum_value > maximum_value:
		return "attribute_range_invalid"
	if default_value < minimum_value or default_value > maximum_value:
		return "attribute_default_out_of_range"
	if default_value == INF or default_value == -INF:
		return "attribute_default_not_finite"
	return ""


func clamp(value: float) -> float:
	return clampf(value, minimum_value, maximum_value)
