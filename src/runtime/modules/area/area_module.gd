class_name AreaModule
extends RefCounted

const DomainEventScript = preload("res://src/runtime/core/core_domain_event.gd")
const ResolverScript = preload("res://src/runtime/modules/area/area_query_action_resolver.gd")

var _areas: Dictionary = {}
var _next_sequence: int = 1


func register_actions(action_registry: RefCounted) -> String:
	if action_registry == null or not action_registry.has_method("register_action"):
		return "area_action_registry_missing"
	if action_registry.has_action("module.area.query"):
		return ""
	return action_registry.register_action("module.area.query", ResolverScript.new(self))


func create_area(definition_id: String, current_tick: int) -> String:
	if definition_id.is_empty():
		return ""
	var area_id := "%s#%d" % [definition_id, _next_sequence]
	_areas[area_id] = {"area_id": area_id, "definition_id": definition_id, "sequence": _next_sequence, "members": [], "last_observation": 0, "created_tick": current_tick}
	_next_sequence += 1
	return area_id


func observe(area_id: String, observation_sequence: int, entity_ids: Array[String], current_tick: int) -> Array[RefCounted]:
	var area: Dictionary = _areas.get(area_id, {})
	if area.is_empty() or observation_sequence <= int(area.last_observation):
		return []
	var next_members: Array[String] = []
	next_members.assign(entity_ids)
	next_members.sort()
	var previous: Array[String] = []
	previous.assign(area.members)
	var events: Array[RefCounted] = []
	for entity_id: String in next_members:
		if not previous.has(entity_id):
			events.append(DomainEventScript.new("area.entered", {"area_id": area_id, "entity_id": entity_id}, "", current_tick, 0))
	for entity_id: String in previous:
		if not next_members.has(entity_id):
			events.append(DomainEventScript.new("area.exited", {"area_id": area_id, "entity_id": entity_id}, "", current_tick, 0))
	area.members = next_members
	area.last_observation = observation_sequence
	return events


func members(area_id: String) -> Array[String]:
	var area: Dictionary = _areas.get(area_id, {})
	var result: Array[String] = []
	if not area.is_empty():
		result.assign(area.members)
	return result


func destroy_area(area_id: String) -> String:
	if not _areas.has(area_id):
		return "unknown_area"
	_areas.erase(area_id)
	return ""


func snapshot() -> Dictionary:
	return {"next_sequence": _next_sequence, "areas": _areas.duplicate(true)}
