class_name CoreAttributeModifier
extends RefCounted

var modifier_id: String = ""
var attribute_id: String = ""
var operation: String = "final_add"
var magnitude: float = 0.0
var priority: int = 0
var source_id: String = ""
var sequence: int = 0


func snapshot() -> Dictionary:
	return {
		"modifier_id": modifier_id,
		"attribute_id": attribute_id,
		"operation": operation,
		"magnitude": magnitude,
		"priority": priority,
		"source_id": source_id,
		"sequence": sequence,
	}
