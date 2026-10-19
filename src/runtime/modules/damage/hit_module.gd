class_name HitModule
extends RefCounted

const DomainEventScript = preload("res://src/runtime/core/core_domain_event.gd")
const HitResultScript = preload("res://src/runtime/modules/damage/hit_result.gd")

func resolve(
	source_entity_id: String,
	target_entity_id: String,
	outcome: String = "success",
	reason: String = "",
	logical_tick: int = 0
) -> RefCounted:
	var result := HitResultScript.new()
	result.source_entity_id = source_entity_id
	result.target_entity_id = target_entity_id
	result.outcome = outcome
	result.reason = reason
	var event_type := "hit.resolved" if result.accepted() else "hit.rejected"
	return DomainEventScript.new(
		event_type,
		result.snapshot(),
		"",
		logical_tick,
		0,
		source_entity_id,
		[target_entity_id]
	)
