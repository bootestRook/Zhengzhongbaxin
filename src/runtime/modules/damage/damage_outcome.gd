class_name DamageOutcome
extends RefCounted

var source_entity_id: String = ""
var target_entity_id: String = ""
var attribute_id: String = ""
var requested: float = 0.0
var mitigated: float = 0.0
var absorbed: float = 0.0
var applied: float = 0.0
var remaining: float = 0.0
var flags: Array[String] = []
var component_results: Array[Dictionary] = []


func snapshot() -> Dictionary:
	return {
		"source_entity_id": source_entity_id,
		"target_entity_id": target_entity_id,
		"attribute_id": attribute_id,
		"requested": requested,
		"mitigated": mitigated,
		"absorbed": absorbed,
		"applied": applied,
		"remaining": remaining,
		"flags": flags.duplicate(),
		"component_results": component_results.duplicate(true),
	}
