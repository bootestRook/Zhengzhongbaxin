class_name CoreEventTrace
extends RefCounted

var max_entries: int = 256
var _entries: Array[Dictionary] = []


func _init(entry_limit: int = 256) -> void:
	max_entries = maxi(1, entry_limit)


func record(request: RefCounted, facts: Array[RefCounted], handler_trace: Array[Dictionary], logical_tick: int, error_code: String = "") -> void:
	var fact_ids: Array[String] = []
	var facts_snapshot: Array[Dictionary] = []
	for fact: RefCounted in facts:
		fact_ids.append(String(fact.event_id))
		facts_snapshot.append(
			{
				"event_type": fact.event_type,
				"source_entity_id": fact.source_entity_id,
				"target_entity_ids": fact.target_entity_ids.duplicate(),
				"cause_chain": fact.cause_chain.duplicate(),
				"logical_tick": fact.logical_tick,
				"payload": fact.payload.duplicate(true),
			}
		)
	_entries.append(
		{
			"event_id": request.event_id,
			"event_type": request.event_type,
			"request_payload": request.payload.duplicate(true),
			"source_entity_id": request.source_entity_id,
			"target_entity_ids": request.target_entity_ids.duplicate(),
			"logical_tick": logical_tick,
			"cause_chain": request.cause_chain.duplicate(),
			"fact_ids": fact_ids,
			"facts": facts_snapshot,
			"handler_trace": handler_trace.duplicate(true),
			"error_code": error_code,
		}
		)
	while _entries.size() > max_entries:
		_entries.pop_front()


func entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func snapshot() -> Dictionary:
	return {"max_entries": max_entries, "entries": entries()}


func restore(snapshot: Dictionary) -> String:
	if typeof(snapshot.get("entries", null)) != TYPE_ARRAY:
		return "event_trace_snapshot_invalid"
	max_entries = maxi(1, int(snapshot.get("max_entries", max_entries)))
	_entries = snapshot.entries.duplicate(true)
	while _entries.size() > max_entries:
		_entries.pop_front()
	return ""
