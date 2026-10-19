class_name CoreEventRequest
extends RefCounted

var event_id: String = ""
var event_type: String = ""
var source_entity_id: String = ""
var target_entity_ids: Array[String] = []
var payload: Dictionary = {}
var cause_chain: Array[String] = []
var depth: int = 0


func _init(
	request_event_type: String = "",
	request_payload: Dictionary = {},
	request_source_entity_id: String = "",
	request_target_entity_ids: Array[String] = [],
	request_event_id: String = "",
	request_depth: int = 0,
	request_cause_chain: Array[String] = []
) -> void:
	event_type = request_event_type
	payload = request_payload.duplicate(true)
	source_entity_id = request_source_entity_id
	target_entity_ids = request_target_entity_ids.duplicate()
	event_id = request_event_id
	depth = request_depth
	cause_chain = request_cause_chain.duplicate()


func child(child_event_type: String, child_payload: Dictionary = {}) -> CoreEventRequest:
	var child_chain := cause_chain.duplicate()
	child_chain.append(event_id)
	return CoreEventRequest.new(
		child_event_type,
		child_payload,
		source_entity_id,
		target_entity_ids,
		"",
		depth + 1,
		child_chain
	)
