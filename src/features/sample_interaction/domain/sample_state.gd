class_name SampleState
extends RefCounted

var instance_id: String = "sample_000001"
var definition_id: String = "sample.interaction_target"
var value: int = 0
var maximum: int = 10
var completed: bool = false


func snapshot() -> Dictionary:
	return {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"value": value,
		"maximum": maximum,
		"completed": completed,
	}


func restore(data: Dictionary) -> String:
	var restored_maximum := int(data.get("maximum", 0))
	var restored_value := int(data.get("value", -1))
	if restored_maximum <= 0 or restored_value < 0 or restored_value > restored_maximum:
		return "invalid_sample_state_range"
	instance_id = String(data.get("instance_id", "sample_000001"))
	definition_id = String(data.get("definition_id", "sample.interaction_target"))
	maximum = restored_maximum
	value = restored_value
	completed = bool(data.get("completed", value >= maximum))
	return ""
