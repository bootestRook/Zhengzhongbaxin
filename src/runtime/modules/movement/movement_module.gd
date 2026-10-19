class_name MovementModule
extends RefCounted

const DomainEventScript = preload("res://src/runtime/core/core_domain_event.gd")
const ResolverScript = preload("res://src/runtime/modules/movement/movement_action_resolver.gd")

var _positions: Dictionary = {}
var _world_port: RefCounted


func _init(world_port: RefCounted = null) -> void:
	_world_port = world_port


func register_actions(action_registry: RefCounted) -> String:
	if action_registry == null or not action_registry.has_method("register_action"):
		return "movement_action_registry_missing"
	if action_registry.has_action("module.movement.move"):
		return ""
	return action_registry.register_action("module.movement.move", ResolverScript.new(self))


func set_position(entity_id: String, position: Vector3) -> String:
	if entity_id.is_empty() or not _finite_vector(position):
		return "movement_position_invalid"
	_positions[entity_id] = position
	return ""


func position(entity_id: String) -> Vector3:
	return _positions.get(entity_id, Vector3.ZERO)


func move(entity_id: String, displacement: Vector3, mode: String = "add", current_tick: int = 0) -> RefCounted:
	if entity_id.is_empty() or not _finite_vector(displacement):
		return null
	var before := position(entity_id)
	var after := displacement if mode == "set" else before + displacement
	if mode not in ["add", "set"] or not _finite_vector(after):
		return null
	_positions[entity_id] = after
	if _world_port != null and _world_port.has_method("move_entity"):
		_world_port.move_entity(entity_id, before, after)
	return DomainEventScript.new(
		"movement.committed",
		{"entity_id": entity_id, "before": before, "after": after, "mode": mode},
		"",
		current_tick,
		0
	)


func snapshot() -> Dictionary:
	var positions: Dictionary = {}
	for entity_id: String in _positions:
		var value: Vector3 = _positions[entity_id]
		positions[entity_id] = {"x": value.x, "y": value.y, "z": value.z}
	return {"positions": positions}


func _finite_vector(value: Vector3) -> bool:
	return value.x != INF and value.x != -INF and value.x == value.x and value.y != INF and value.y != -INF and value.y == value.y and value.z != INF and value.z != -INF and value.z == value.z
