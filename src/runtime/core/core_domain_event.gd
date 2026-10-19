class_name CoreDomainEvent
extends RefCounted

var event_id: String = ""
var event_type: String = ""
var logical_tick: int = 0
var sequence: int = 0
var source_entity_id: String = ""
var target_entity_ids: Array[String] = []
var cause_chain: Array[String] = []
var payload: Dictionary = {}


func _init(
	fact_event_type: String = "",
	fact_payload: Dictionary = {},
	fact_event_id: String = "",
	fact_logical_tick: int = 0,
	fact_sequence: int = 0,
	fact_source_entity_id: String = "",
	fact_target_entity_ids: Array[String] = [],
	fact_cause_chain: Array[String] = []
) -> void:
	event_type = fact_event_type
	payload = fact_payload.duplicate(true)
	event_id = fact_event_id
	logical_tick = fact_logical_tick
	sequence = fact_sequence
	source_entity_id = fact_source_entity_id
	target_entity_ids = fact_target_entity_ids.duplicate()
	cause_chain = fact_cause_chain.duplicate()
