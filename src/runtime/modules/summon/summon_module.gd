class_name SummonModule
extends RefCounted

const DomainEventScript = preload("res://src/runtime/core/core_domain_event.gd")
const ResolverScript = preload("res://src/runtime/modules/summon/summon_action_resolver.gd")

var _state: RefCounted
var _summons: Dictionary = {}
var _next_sequence: int = 1
var _factory_port: RefCounted


func _init(combat_state: RefCounted, factory_port: RefCounted = null) -> void:
	_state = combat_state
	_factory_port = factory_port


func register_actions(action_registry: RefCounted) -> String:
	if action_registry == null or not action_registry.has_method("register_action"):
		return "summon_action_registry_missing"
	if action_registry.has_action("module.summon.create"):
		return ""
	return action_registry.register_action("module.summon.create", ResolverScript.new(self))


func summon(source_entity_id: String, definition_id: String, current_tick: int, lifetime_ticks: int = -1) -> RefCounted:
	if _state == null or source_entity_id.is_empty() or definition_id.is_empty() or lifetime_ticks == 0 or lifetime_ticks < -1:
		return null
	var entity_id := "%s#%d" % [definition_id, _next_sequence]
	var entity: RefCounted = _state.create_entity(entity_id)
	if entity == null:
		return null
	var record := {
		"entity_id": entity_id,
		"source_entity_id": source_entity_id,
		"definition_id": definition_id,
		"spawned_tick": current_tick,
		"expires_tick": current_tick + lifetime_ticks if lifetime_ticks > 0 else -1,
	}
	_summons[entity_id] = record
	_next_sequence += 1
	if _factory_port != null and _factory_port.has_method("initialize_summon"):
		_factory_port.initialize_summon(entity, record.duplicate(true))
	return DomainEventScript.new("summon.created", record, "", current_tick, 0)


func despawn(entity_id: String, current_tick: int) -> RefCounted:
	if not _summons.has(entity_id):
		return null
	if _state.remove_entity(entity_id) != "":
		return null
	_summons.erase(entity_id)
	return DomainEventScript.new("summon.removed", {"entity_id": entity_id}, "", current_tick, 0)


func expire(current_tick: int) -> Array[RefCounted]:
	var events: Array[RefCounted] = []
	for entity_id: String in _summons.keys():
		var record: Dictionary = _summons[entity_id]
		if int(record.expires_tick) >= 0 and current_tick >= int(record.expires_tick):
			var event = despawn(entity_id, current_tick)
			if event != null:
				events.append(event)
	return events


func snapshot() -> Dictionary:
	return {"next_sequence": _next_sequence, "summons": _summons.duplicate(true)}
