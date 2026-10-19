class_name CoreTriggerRegistry
extends RefCounted

const TriggerScript = preload("res://src/runtime/core/core_trigger_definition.gd")
const HandlerScript = preload("res://src/runtime/core/core_trigger_handler.gd")

var _definitions: Dictionary = {}


func register(definition: RefCounted) -> String:
	if not (definition is CoreTriggerDefinition):
		return "invalid_trigger_definition"
	var validation_error: String = definition.validate()
	if not validation_error.is_empty():
		return validation_error
	if _definitions.has(definition.trigger_id):
		return "duplicate_trigger_id"
	_definitions[definition.trigger_id] = definition
	return ""


func definition(trigger_id: String) -> RefCounted:
	return _definitions.get(trigger_id)


func create_handler(trigger_id: String, condition_registry: RefCounted = null) -> RefCounted:
	var definition: RefCounted = _definitions.get(trigger_id)
	if definition == null or not (definition is TriggerScript):
		return null
	return HandlerScript.new(definition, condition_registry)
