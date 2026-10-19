class_name CoreEffectStore
extends RefCounted

const EffectDefinitionScript = preload("res://src/runtime/core/core_effect_definition.gd")
const EffectInstanceScript = preload("res://src/runtime/core/core_effect_instance.gd")

var _definitions: Dictionary = {}
var _instances: Dictionary = {}
var _next_sequence: int = 1
var _tag_store: RefCounted
var _attribute_store: RefCounted


func _init(tag_store: RefCounted = null, attribute_store: RefCounted = null) -> void:
	_tag_store = tag_store
	_attribute_store = attribute_store


func register_definition(definition: RefCounted) -> String:
	if not (definition is EffectDefinitionScript):
		return "invalid_effect_definition"
	var validation_error: String = definition.validate()
	if not validation_error.is_empty():
		return validation_error
	if _definitions.has(definition.effect_id):
		return "duplicate_effect_id"
	_definitions[definition.effect_id] = definition
	return ""


func apply(effect_id: String, source_entity_id: String, current_tick: int, target_entity_id: String = "") -> RefCounted:
	var definition: RefCounted = _definitions.get(effect_id)
	if definition == null:
		return null
	var existing: RefCounted = _matching_instance(definition, source_entity_id, target_entity_id)
	if existing != null:
		match definition.stacking_policy:
			"reject":
				return null
			"replace":
				remove(existing.instance_id)
			"refresh":
				existing.applied_tick = current_tick
				existing.expires_tick = current_tick + definition.duration_ticks if definition.duration_ticks >= 0 else -1
				existing.next_period_tick = current_tick + definition.period_ticks if definition.period_ticks > 0 else -1
				return existing
			"add_stack":
				existing.stacks = mini(existing.stacks + 1, definition.max_stacks)
				existing.applied_tick = current_tick
				existing.expires_tick = current_tick + definition.duration_ticks if definition.duration_ticks >= 0 else -1
				existing.next_period_tick = current_tick + definition.period_ticks if definition.period_ticks > 0 else -1
				return existing
	var instance := EffectInstanceScript.new()
	instance.instance_id = "%s#%d" % [effect_id, _next_sequence]
	instance.effect_id = effect_id
	instance.source_entity_id = source_entity_id
	instance.target_entity_id = target_entity_id
	instance.applied_tick = current_tick
	instance.next_period_tick = current_tick + definition.period_ticks if definition.period_ticks > 0 else -1
	instance.expires_tick = current_tick + definition.duration_ticks if definition.duration_ticks >= 0 else -1
	_instances[instance.instance_id] = instance
	_next_sequence += 1
	var attach_error: String = _attach_definition(instance, definition)
	if not attach_error.is_empty():
		_detach_instance(instance)
		_instances.erase(instance.instance_id)
		return null
	return instance


func remove(instance_id: String) -> String:
	var instance: RefCounted = _instances.get(instance_id)
	if instance == null:
		return "unknown_effect_instance"
	var definition: RefCounted = _definitions.get(instance.effect_id)
	_detach_instance(instance)
	instance.lifecycle = "removed"
	_instances.erase(instance_id)
	return ""


func instance(instance_id: String) -> RefCounted:
	return _instances.get(instance_id)


func active_instances() -> Array[RefCounted]:
	var result: Array[RefCounted] = []
	for instance_id: String in _instances:
		if _instances[instance_id].lifecycle == "active":
			result.append(_instances[instance_id])
	result.sort_custom(func(left: RefCounted, right: RefCounted) -> bool: return left.instance_id < right.instance_id)
	return result


func expire_at(current_tick: int) -> Array[String]:
	var expired: Array[String] = []
	for instance: RefCounted in active_instances():
		if instance.is_expired(current_tick):
			expired.append(instance.instance_id)
			remove(instance.instance_id)
	return expired


func period_due_at(current_tick: int) -> Array[String]:
	var due: Array[String] = []
	for instance: RefCounted in active_instances():
		if instance.is_period_due(current_tick):
			due.append(instance.instance_id)
			var definition: RefCounted = _definitions.get(instance.effect_id)
			if definition != null and definition.period_ticks > 0:
				instance.next_period_tick += definition.period_ticks
	return due


func snapshot() -> Dictionary:
	var instances: Dictionary = {}
	for instance_id: String in _instances:
		instances[instance_id] = _instances[instance_id].snapshot()
	return {"next_sequence": _next_sequence, "instances": instances}


func full_snapshot() -> Dictionary:
	var definitions: Dictionary = {}
	for effect_id: String in _definitions:
		definitions[effect_id] = _definitions[effect_id].snapshot()
	var result := snapshot()
	result["definitions"] = definitions
	return result


func restore(snapshot: Dictionary) -> String:
	var raw_instances: Variant = snapshot.get("instances", null)
	if typeof(raw_instances) != TYPE_DICTIONARY:
		return "effect_snapshot_invalid"
	var raw_definitions: Variant = snapshot.get("definitions", null)
	if typeof(raw_definitions) == TYPE_DICTIONARY:
		for effect_id: String in raw_definitions:
			if not _definitions.has(effect_id):
				var data: Dictionary = raw_definitions[effect_id]
				var definition := EffectDefinitionScript.new(
					String(data.get("effect_id", effect_id)),
					int(data.get("duration_ticks", -1)),
					int(data.get("period_ticks", 0)),
					data.get("granted_tags", [])
				)
				definition.stacking_policy = String(data.get("stacking_policy", "independent"))
				definition.stacking_key = String(data.get("stacking_key", definition.effect_id))
				definition.max_stacks = int(data.get("max_stacks", 1))
				definition.modifiers = data.get("modifiers", []).duplicate(true)
				definition.executions = data.get("executions", []).duplicate(true)
				var definition_error := register_definition(definition)
				if not definition_error.is_empty():
					return definition_error
	for existing: RefCounted in active_instances():
		_detach_instance(existing)
	_instances.clear()
	for instance_id: String in raw_instances:
		var data: Variant = raw_instances[instance_id]
		if typeof(data) != TYPE_DICTIONARY:
			return "effect_instance_snapshot_invalid"
		var definition: RefCounted = _definitions.get(String(data.get("effect_id", "")))
		if definition == null:
			return "effect_definition_missing_for_snapshot"
		var instance := EffectInstanceScript.new()
		instance.instance_id = String(data.get("instance_id", instance_id))
		instance.effect_id = String(data.get("effect_id", ""))
		instance.source_entity_id = String(data.get("source_entity_id", ""))
		instance.target_entity_id = String(data.get("target_entity_id", ""))
		instance.applied_tick = int(data.get("applied_tick", 0))
		instance.next_period_tick = int(data.get("next_period_tick", -1))
		instance.expires_tick = int(data.get("expires_tick", -1))
		instance.stacks = int(data.get("stacks", 1))
		instance.lifecycle = String(data.get("lifecycle", "active"))
		var saved_grants: Variant = data.get("grant_handles", null)
		var saved_modifiers: Variant = data.get("modifier_handles", null)
		if saved_grants is Array:
			instance.grant_handles.assign(saved_grants)
		if saved_modifiers is Array:
			instance.modifier_handles.assign(saved_modifiers)
		_instances[instance.instance_id] = instance
		if saved_grants == null and saved_modifiers == null:
			var attach_error: String = _attach_definition(instance, definition)
			if not attach_error.is_empty():
				_detach_instance(instance)
				_instances.erase(instance.instance_id)
				return attach_error
	_next_sequence = int(snapshot.get("next_sequence", 1))
	return ""


func _matching_instance(definition: RefCounted, source_entity_id: String, target_entity_id: String) -> RefCounted:
	if definition.stacking_policy == "independent":
		return null
	for instance: RefCounted in active_instances():
		if instance.effect_id == definition.effect_id and instance.source_entity_id == source_entity_id and instance.target_entity_id == target_entity_id:
			return instance
	return null


func _attach_definition(instance: RefCounted, definition: RefCounted) -> String:
	if _tag_store != null:
		for tag_id: String in definition.granted_tags:
			var handle: String = _tag_store.grant(tag_id, instance.instance_id)
			if handle.is_empty() or not handle.contains("#"):
				return handle if not handle.is_empty() else "effect_tag_grant_failed"
			instance.grant_handles.append(handle)
	if _attribute_store != null:
		for modifier: Dictionary in definition.modifiers:
			var handle: String = _attribute_store.add_modifier(
				String(modifier.get("attribute_id", "")),
				String(modifier.get("operation", "final_add")),
				float(modifier.get("magnitude", 0.0)),
				instance.instance_id,
				int(modifier.get("priority", 0))
			)
			if handle.is_empty() or not handle.contains("#"):
				return handle if not handle.is_empty() else "effect_modifier_attach_failed"
			instance.modifier_handles.append(handle)
	return ""


func _detach_instance(instance: RefCounted) -> void:
	if _tag_store != null:
		for handle: String in instance.grant_handles:
			_tag_store.revoke(handle)
	if _attribute_store != null:
		for handle: String in instance.modifier_handles:
			_attribute_store.remove_modifier(handle)
	instance.grant_handles.clear()
	instance.modifier_handles.clear()
