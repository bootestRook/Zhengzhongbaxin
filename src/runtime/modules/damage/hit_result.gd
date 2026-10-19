class_name HitResult
extends RefCounted

var outcome: String = "success"
var source_entity_id: String = ""
var target_entity_id: String = ""
var reason: String = ""


func accepted() -> bool:
	return outcome == "success"


func snapshot() -> Dictionary:
	return {
		"outcome": outcome,
		"source_entity_id": source_entity_id,
		"target_entity_id": target_entity_id,
		"reason": reason,
	}
