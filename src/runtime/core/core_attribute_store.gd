class_name CoreAttributeStore
extends RefCounted

const DefinitionScript = preload("res://src/runtime/core/core_attribute_definition.gd")
const ModifierScript = preload("res://src/runtime/core/core_attribute_modifier.gd")
const OPERATIONS: Array[String] = ["base_add", "multiply", "final_add", "override"]

var _definitions: Dictionary = {}
var _base_values: Dictionary = {}
var _values: Dictionary = {}
var _modifiers: Dictionary = {}
var _next_modifier_sequence: int = 1


func register_definition(definition: RefCounted) -> String:
	if not (definition is DefinitionScript):
		return "invalid_attribute_definition"
	var validation_error: String = definition.validate()
	if not validation_error.is_empty():
		return validation_error
	if _definitions.has(definition.attribute_id):
		return "duplicate_attribute_id"
	_definitions[definition.attribute_id] = definition
	_base_values[definition.attribute_id] = definition.default_value
	_values[definition.attribute_id] = definition.default_value
	return ""


func has(attribute_id: String) -> bool:
	return _definitions.has(attribute_id)


func definition(attribute_id: String) -> RefCounted:
	return _definitions.get(attribute_id)


func base_value(attribute_id: String, fallback: float = 0.0) -> float:
	if not _definitions.has(attribute_id):
		return fallback
	return float(_base_values.get(attribute_id, fallback))


func value(attribute_id: String, fallback: float = 0.0) -> float:
	if not _definitions.has(attribute_id):
		return fallback
	_recompute(attribute_id)
	return float(_values.get(attribute_id, fallback))


func set_value(attribute_id: String, next_value: float) -> String:
	return set_base_value(attribute_id, next_value)


func set_base_value(attribute_id: String, next_value: float) -> String:
	var attribute_definition: RefCounted = _definitions.get(attribute_id)
	if attribute_definition == null:
		return "unknown_attribute"
	if not _is_finite(next_value):
		return "attribute_value_not_finite"
	_base_values[attribute_id] = attribute_definition.clamp(next_value)
	_recompute(attribute_id)
	return ""


func add_modifier(
	attribute_id: String,
	operation: String,
	magnitude: float,
	source_id: String = "",
	priority: int = 0
) -> String:
	if not _definitions.has(attribute_id):
		return "unknown_attribute"
	if not OPERATIONS.has(operation):
		return "unknown_attribute_modifier_operation"
	if not _is_finite(magnitude):
		return "attribute_modifier_not_finite"
	var modifier := ModifierScript.new()
	modifier.attribute_id = attribute_id
	modifier.operation = operation
	modifier.magnitude = magnitude
	modifier.priority = priority
	modifier.source_id = source_id
	modifier.sequence = _next_modifier_sequence
	modifier.modifier_id = "%s#%d" % [attribute_id, _next_modifier_sequence]
	_next_modifier_sequence += 1
	_modifiers[modifier.modifier_id] = modifier
	_recompute(attribute_id)
	return modifier.modifier_id


func remove_modifier(modifier_id: String) -> String:
	var modifier: RefCounted = _modifiers.get(modifier_id)
	if modifier == null:
		return "unknown_attribute_modifier"
	_modifiers.erase(modifier_id)
	_recompute(modifier.attribute_id)
	return ""


func modifier(modifier_id: String) -> RefCounted:
	return _modifiers.get(modifier_id)


func modifiers_for(attribute_id: String) -> Array[RefCounted]:
	var result: Array[RefCounted] = []
	for modifier_id: String in _modifiers:
		var modifier: RefCounted = _modifiers[modifier_id]
		if modifier.attribute_id == attribute_id:
			result.append(modifier)
	result.sort_custom(func(left: RefCounted, right: RefCounted) -> bool:
		if left.operation != right.operation:
			return OPERATIONS.find(left.operation) < OPERATIONS.find(right.operation)
		if left.priority != right.priority:
			return left.priority > right.priority
		if left.sequence != right.sequence:
			return left.sequence < right.sequence
		return left.modifier_id < right.modifier_id
	)
	return result


func snapshot() -> Dictionary:
	var modifiers: Dictionary = {}
	for modifier_id: String in _modifiers:
		modifiers[modifier_id] = _modifiers[modifier_id].snapshot()
	return {
		"base_values": _base_values.duplicate(true),
		"values": _values.duplicate(true),
		"modifiers": modifiers,
		"next_modifier_sequence": _next_modifier_sequence,
	}


func full_snapshot() -> Dictionary:
	var definitions: Dictionary = {}
	for attribute_id: String in _definitions:
		var definition: RefCounted = _definitions[attribute_id]
		definitions[attribute_id] = {
			"attribute_id": definition.attribute_id,
			"default_value": definition.default_value,
			"minimum_value": definition.minimum_value,
			"maximum_value": definition.maximum_value,
		}
	var result := snapshot()
	result["definitions"] = definitions
	return result


func restore(snapshot_data: Dictionary) -> String:
	var raw_definitions: Variant = snapshot_data.get("definitions", null)
	if typeof(raw_definitions) == TYPE_DICTIONARY:
		for attribute_id: String in raw_definitions:
			if not _definitions.has(attribute_id):
				var data: Dictionary = raw_definitions[attribute_id]
				var register_error := register_definition(DefinitionScript.new(
					String(data.get("attribute_id", attribute_id)),
					float(data.get("default_value", 0.0)),
					float(data.get("minimum_value", -INF)),
					float(data.get("maximum_value", INF))
				))
				if not register_error.is_empty():
					return register_error
	var raw_base: Variant = snapshot_data.get("base_values", null)
	var raw_values: Variant = snapshot_data.get("values", snapshot_data)
	if typeof(raw_base) != TYPE_DICTIONARY or typeof(raw_values) != TYPE_DICTIONARY:
		return "attribute_snapshot_invalid"
	for attribute_id: String in _definitions:
		if not raw_base.has(attribute_id) and not raw_values.has(attribute_id):
			return "attribute_snapshot_missing"
		var candidate: float = float(raw_base.get(attribute_id, raw_values.get(attribute_id, 0.0)))
		var set_error: String = set_base_value(attribute_id, candidate)
		if not set_error.is_empty():
			return set_error
	_modifiers.clear()
	var raw_modifiers: Variant = snapshot_data.get("modifiers", {})
	if typeof(raw_modifiers) != TYPE_DICTIONARY:
		return "attribute_modifiers_snapshot_invalid"
	for modifier_id: String in raw_modifiers:
		var data: Variant = raw_modifiers[modifier_id]
		if typeof(data) != TYPE_DICTIONARY:
			return "attribute_modifier_snapshot_invalid"
		var modifier := ModifierScript.new()
		modifier.modifier_id = String(data.get("modifier_id", modifier_id))
		modifier.attribute_id = String(data.get("attribute_id", ""))
		modifier.operation = String(data.get("operation", "final_add"))
		modifier.magnitude = float(data.get("magnitude", 0.0))
		modifier.priority = int(data.get("priority", 0))
		modifier.source_id = String(data.get("source_id", ""))
		modifier.sequence = int(data.get("sequence", 0))
		if not _definitions.has(modifier.attribute_id) or not OPERATIONS.has(modifier.operation):
			return "attribute_modifier_reference_invalid"
		if not _is_finite(modifier.magnitude):
			return "attribute_modifier_not_finite"
		_modifiers[modifier.modifier_id] = modifier
	_next_modifier_sequence = int(snapshot_data.get("next_modifier_sequence", 1))
	for attribute_id: String in _definitions:
		_recompute(attribute_id)
	return ""


func aggregation_trace(attribute_id: String) -> Array[Dictionary]:
	var trace: Array[Dictionary] = [{"kind": "base", "value": base_value(attribute_id)}]
	var current := base_value(attribute_id)
	var modifiers := modifiers_for(attribute_id)
	var override_found := false
	for modifier: RefCounted in modifiers:
		if modifier.operation == "override":
			if override_found:
				trace.append({"kind": "modifier", "modifier_id": modifier.modifier_id, "operation": modifier.operation, "magnitude": modifier.magnitude, "applied": false, "reason": "shadowed"})
				continue
			current = modifier.magnitude
			override_found = true
		else:
			match modifier.operation:
				"base_add", "final_add": current += modifier.magnitude
				"multiply": current *= 1.0 + modifier.magnitude
		trace.append({"kind": "modifier", "modifier_id": modifier.modifier_id, "operation": modifier.operation, "magnitude": modifier.magnitude, "applied": true, "value": current})
	var definition: RefCounted = _definitions.get(attribute_id)
	if definition != null:
		current = definition.clamp(current)
	trace.append({"kind": "clamp", "value": current})
	return trace


func _recompute(attribute_id: String) -> void:
	if not _definitions.has(attribute_id):
		return
	var current := base_value(attribute_id)
	var override_found := false
	for modifier: RefCounted in modifiers_for(attribute_id):
		if modifier.operation == "override":
			if override_found:
				continue
			current = modifier.magnitude
			override_found = true
		else:
			match modifier.operation:
				"base_add", "final_add": current += modifier.magnitude
				"multiply": current *= 1.0 + modifier.magnitude
	_values[attribute_id] = _definitions[attribute_id].clamp(current)


func _is_finite(value: float) -> bool:
	return value != INF and value != -INF and value == value
