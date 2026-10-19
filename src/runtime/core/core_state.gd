class_name CoreState
extends RefCounted

const EntityScript = preload("res://src/runtime/core/core_entity_instance.gd")

var logical_tick: int = 0
var _next_entity_sequence: int = 1
var _entities: Dictionary = {}


func create_entity(entity_id: String) -> RefCounted:
	if entity_id.is_empty() or _entities.has(entity_id):
		return null
	var entity := EntityScript.new(entity_id, _next_entity_sequence)
	_next_entity_sequence += 1
	_entities[entity_id] = entity
	return entity


func remove_entity(entity_id: String) -> String:
	if not _entities.has(entity_id):
		return "unknown_entity"
	_entities.erase(entity_id)
	return ""


func entity(entity_id: String) -> RefCounted:
	return _entities.get(entity_id)


func entities_in_sequence_order() -> Array[RefCounted]:
	var result: Array[RefCounted] = []
	for entity: RefCounted in _entities.values():
		result.append(entity)
	result.sort_custom(func(left: RefCounted, right: RefCounted) -> bool: return left.sequence < right.sequence)
	return result


func advance_tick() -> int:
	logical_tick += 1
	return logical_tick


func snapshot() -> Dictionary:
	var entity_snapshots: Dictionary = {}
	for entity_id: String in _entities:
		entity_snapshots[entity_id] = _entities[entity_id].snapshot()
	return {
		"logical_tick": logical_tick,
		"next_entity_sequence": _next_entity_sequence,
		"entities": entity_snapshots,
	}


func restore(snapshot: Dictionary) -> String:
	var raw_entities: Variant = snapshot.get("entities", null)
	if typeof(raw_entities) != TYPE_DICTIONARY:
		return "state_snapshot_invalid"
	var existing_ids: Array[String] = []
	for entity_id: String in _entities:
		existing_ids.append(entity_id)
	for entity_id: String in existing_ids:
		if not raw_entities.has(entity_id):
			_entities.erase(entity_id)
	for entity_id: String in raw_entities:
		var current: RefCounted = _entities.get(entity_id)
		if current == null:
			var raw_entity: Dictionary = raw_entities[entity_id]
			current = EntityScript.new(entity_id, int(raw_entity.get("sequence", 0)))
			_entities[entity_id] = current
		var error: String = current.restore(raw_entities[entity_id])
		if not error.is_empty():
			return error
	logical_tick = int(snapshot.get("logical_tick", logical_tick))
	_next_entity_sequence = int(snapshot.get("next_entity_sequence", _next_entity_sequence))
	return ""
