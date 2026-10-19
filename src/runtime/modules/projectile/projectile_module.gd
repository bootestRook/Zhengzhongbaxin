class_name ProjectileModule
extends RefCounted

const DefinitionScript = preload("res://src/runtime/modules/projectile/projectile_definition.gd")
const InstanceScript = preload("res://src/runtime/modules/projectile/projectile_instance.gd")
const DomainEventScript = preload("res://src/runtime/core/core_domain_event.gd")
const ResolverScript = preload("res://src/runtime/modules/projectile/projectile_action_resolver.gd")

var _definitions: Dictionary = {}
var _instances: Dictionary = {}
var _next_sequence: int = 1
var _world_port: RefCounted


func _init(world_port: RefCounted = null) -> void:
	_world_port = world_port


func register_definition(definition: RefCounted) -> String:
	if not (definition is DefinitionScript):
		return "invalid_projectile_definition"
	var validation_error: String = definition.validate()
	if not validation_error.is_empty():
		return validation_error
	if _definitions.has(definition.definition_id):
		return "duplicate_projectile_definition"
	_definitions[definition.definition_id] = definition
	return ""


func definition(definition_id: String) -> RefCounted:
	return _definitions.get(definition_id)


func has_definition(definition_id: String) -> bool:
	return _definitions.has(definition_id)


func register_actions(action_registry: RefCounted) -> String:
	if action_registry == null or not action_registry.has_method("register_action"):
		return "projectile_action_registry_missing"
	if action_registry.has_action("module.projectile.spawn"):
		return ""
	return action_registry.register_action("module.projectile.spawn", ResolverScript.new(self))


func spawn(
	source_entity_id: String,
	target_entity_id: String,
	definition_id: String,
	current_tick: int
) -> RefCounted:
	if source_entity_id.is_empty() or target_entity_id.is_empty() or definition_id.is_empty():
		return null
	var definition: RefCounted = _definitions.get(definition_id)
	if definition == null:
		return null
	var instance := InstanceScript.new()
	instance.projectile_id = "%s#%d" % [definition_id, _next_sequence]
	instance.definition_id = definition_id
	instance.source_entity_id = source_entity_id
	instance.target_entity_id = target_entity_id
	instance.spawned_tick = current_tick
	instance.current_tick = current_tick
	instance.expires_tick = current_tick + definition.lifetime_ticks if definition.lifetime_ticks > 0 else -1
	_instances[instance.projectile_id] = instance
	_next_sequence += 1
	if _world_port != null and _world_port.has_method("spawn_projectile"):
		_world_port.spawn_projectile(instance.snapshot())
	return instance


func impact(projectile_id: String, target_entity_id: String, observation_sequence: int, current_tick: int) -> RefCounted:
	var instance: RefCounted = _instances.get(projectile_id)
	if instance == null:
		return null
	if instance.state != "active" or instance.target_entity_id != target_entity_id or current_tick < instance.spawned_tick:
		return null
	if observation_sequence < instance.observation_sequence:
		return null
	instance.observation_sequence = observation_sequence
	instance.current_tick = current_tick
	instance.hit_count += 1
	var definition: RefCounted = _definitions.get(instance.definition_id)
	if definition != null and instance.hit_count >= definition.max_hits:
		instance.state = "impacted"
	return DomainEventScript.new(
		"projectile.impact",
		{
			"projectile_id": projectile_id,
			"definition_id": instance.definition_id,
			"source_entity_id": instance.source_entity_id,
			"target_entity_id": target_entity_id,
			"observation_sequence": observation_sequence,
			"hit_count": instance.hit_count,
		},
		"",
		current_tick,
		0,
		instance.source_entity_id,
		[target_entity_id]
	)


func expire(current_tick: int) -> Array[RefCounted]:
	var events: Array[RefCounted] = []
	for projectile_id: String in _instances:
		var instance: RefCounted = _instances[projectile_id]
		if instance.state == "active" and instance.expires_tick >= 0 and current_tick >= instance.expires_tick:
			instance.current_tick = current_tick
			instance.state = "expired"
			events.append(DomainEventScript.new(
				"projectile.expired",
				{"projectile_id": projectile_id, "definition_id": instance.definition_id},
				"",
				current_tick,
				0,
				instance.source_entity_id,
				[instance.target_entity_id]
			))
	return events


func instance(projectile_id: String) -> RefCounted:
	return _instances.get(projectile_id)


func active_instances() -> Array[RefCounted]:
	var result: Array[RefCounted] = []
	for instance: RefCounted in _instances.values():
		if instance.state == "active":
			result.append(instance)
	result.sort_custom(func(left: RefCounted, right: RefCounted) -> bool: return left.projectile_id < right.projectile_id)
	return result


func snapshot() -> Dictionary:
	var definitions: Dictionary = {}
	for definition_id: String in _definitions:
		definitions[definition_id] = _definitions[definition_id].snapshot()
	var instances: Dictionary = {}
	for projectile_id: String in _instances:
		instances[projectile_id] = _instances[projectile_id].snapshot()
	return {"definitions": definitions, "instances": instances, "next_sequence": _next_sequence}
