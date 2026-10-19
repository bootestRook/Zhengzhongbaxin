class_name CoreExecutionContext
extends RefCounted

var state: RefCounted
var pipeline: RefCounted
var target_resolvers: RefCounted
var source_entity_id: String = ""
var target_entity_ids: Array[String] = []
var values: Dictionary = {}
var logical_tick: int = 0
var event: RefCounted = null
var event_type: String = ""
var event_payload: Dictionary = {}


func _init(
	combat_state: RefCounted = null,
	event_pipeline: RefCounted = null,
	source_id: String = "",
	initial_targets: Array[String] = [],
	resolver_registry: RefCounted = null
) -> void:
	state = combat_state
	pipeline = event_pipeline
	target_resolvers = resolver_registry
	source_entity_id = source_id
	target_entity_ids = initial_targets.duplicate()
	logical_tick = int(state.logical_tick) if state != null else 0


func snapshot_state() -> Dictionary:
	return {
		"state": state.snapshot() if state != null and state.has_method("snapshot") else {},
		"source_entity_id": source_entity_id,
		"target_entity_ids": target_entity_ids.duplicate(),
		"values": values.duplicate(true),
		"logical_tick": logical_tick,
	}


func restore_state(snapshot: Dictionary) -> String:
	if state != null and state.has_method("restore"):
		var state_error: String = state.restore(snapshot.get("state", {}))
		if not state_error.is_empty():
			return state_error
		source_entity_id = String(snapshot.get("source_entity_id", source_entity_id))
		target_entity_ids.assign(snapshot.get("target_entity_ids", []))
		values = snapshot.get("values", {}).duplicate(true)
		logical_tick = int(snapshot.get("logical_tick", logical_tick))
		return ""
	return "execution_context_state_missing"


func set_targets(entity_ids: Array[String]) -> void:
	target_entity_ids = entity_ids.duplicate()


func set_value(key: String, value: Variant) -> String:
	if key.is_empty():
		return "execution_value_key_empty"
	values[key] = value
	return ""


func set_event(domain_event: RefCounted) -> String:
	if domain_event == null:
		return "execution_event_missing"
	event = domain_event
	event_type = String(domain_event.event_type)
	event_payload = domain_event.payload.duplicate(true)
	if not String(domain_event.source_entity_id).is_empty():
		source_entity_id = String(domain_event.source_entity_id)
	if not domain_event.target_entity_ids.is_empty():
		target_entity_ids = domain_event.target_entity_ids.duplicate()
	return ""


func value(key: String, fallback: Variant = null) -> Variant:
	return values.get(key, fallback)


func read_attribute(entity_id: String, attribute_id: String, fallback: float = 0.0) -> float:
	if state == null:
		return fallback
	var entity: RefCounted = state.entity(entity_id)
	if entity == null or not entity.attributes.has(attribute_id):
		return fallback
	return entity.attributes.value(attribute_id, fallback)


func dispatch(request: RefCounted) -> RefCounted:
	if pipeline == null:
		return null
	return pipeline.dispatch(request, logical_tick)


func resolve_target(target_type: String, parameters: Dictionary = {}) -> RefCounted:
	if target_resolvers == null:
		return null
	return target_resolvers.resolve(target_type, self, parameters)
