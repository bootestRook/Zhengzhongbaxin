class_name AbilityExecutionSnapshot
extends RefCounted

var run_id: String = ""
var graph_id: String = ""
var owner_entity_id: String = ""
var state: String = ""
var current_node_id: String = ""
var logical_tick: int = 0
var sequence: int = 0
var last_error_code: String = ""
var waiting_reason: String = ""
var resume_tick: int = -1
var waiting_event_type: String = ""
var waiting_filter: Dictionary = {}
var wait_scope_id: String = ""
var scope_stack: Array[String] = []
var active_edge: Dictionary = {}
var trace: Array[Dictionary] = []
var event_trace: Array[Dictionary] = []
var visited_node_ids: Array[String] = []
var enter_counts: Dictionary = {}
var values: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"run_id": run_id,
		"graph_id": graph_id,
		"owner_entity_id": owner_entity_id,
		"state": state,
		"current_node_id": current_node_id,
		"logical_tick": logical_tick,
		"sequence": sequence,
		"last_error_code": last_error_code,
		"waiting_reason": waiting_reason,
		"resume_tick": resume_tick,
		"waiting_event_type": waiting_event_type,
		"waiting_filter": waiting_filter.duplicate(true),
		"wait_scope_id": wait_scope_id,
		"scope_stack": scope_stack.duplicate(),
		"active_edge": active_edge.duplicate(true),
		"trace": trace.duplicate(true),
		"event_trace": event_trace.duplicate(true),
		"visited_node_ids": visited_node_ids.duplicate(),
		"enter_counts": enter_counts.duplicate(true),
		"values": values.duplicate(true),
	}
