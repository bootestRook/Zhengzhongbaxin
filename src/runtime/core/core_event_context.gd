class_name CoreEventContext
extends RefCounted

var request: RefCounted
var relay: Dictionary
var phase: String = ""
var logical_tick: int = 0
var trace: Array[Dictionary] = []


func _init(event_request: RefCounted, initial_relay: Dictionary) -> void:
	request = event_request
	relay = initial_relay.duplicate(true)


func trace_handler(handler_id: String, priority: int, result_kind: String) -> void:
	trace.append(
		{
			"event_id": request.event_id,
			"event_type": request.event_type,
			"phase": phase,
			"handler_id": handler_id,
			"priority": priority,
			"result": result_kind,
		}
	)
