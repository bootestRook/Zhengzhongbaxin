class_name CoreTriggerHandler
extends RefCounted

const RequestScript = preload("res://src/runtime/core/core_event_request.gd")
const ResultScript = preload("res://src/runtime/core/core_event_handler_result.gd")

var _definition: RefCounted
var _conditions: RefCounted
var _fire_count: int = 0
var _last_fire_tick: int = -1
var _owner_sequence: int = 0


func _init(definition: RefCounted, conditions: RefCounted = null, owner_sequence: int = 0) -> void:
	_definition = definition
	_conditions = conditions
	_owner_sequence = owner_sequence


func handler_id() -> String:
	return "trigger.%s" % _definition.trigger_id


func phase() -> String:
	return "after"


func priority() -> int:
	return int(_definition.priority)


func scope_rank() -> int:
	match String(_definition.scope):
		"source":
			return 0
		"target":
			return 1
		_:
			return 2


func owner_sequence() -> int:
	return _owner_sequence


func handle(context: RefCounted):
	var current_tick := int(context.logical_tick)
	if _definition.max_triggers >= 0 and _fire_count >= _definition.max_triggers:
		return ResultScript.continue_result()
	if _definition.cooldown_ticks > 0 and _last_fire_tick >= 0 and current_tick < _last_fire_tick + _definition.cooldown_ticks:
		return ResultScript.continue_result()
	var cause_tags: Array = context.request.payload.get("cause_tags", [])
	for excluded_tag: String in _definition.excluded_cause_tags:
		if cause_tags.has(excluded_tag):
			return ResultScript.continue_result()
	if not _definition.condition_id.is_empty():
		if _conditions == null:
			return ResultScript.reject_result("trigger_condition_registry_missing")
		var condition = _conditions.evaluate(_definition.condition_id, context, {})
		if not condition.passed:
			return ResultScript.continue_result()
	var cause_chain: Array[String] = context.request.cause_chain.duplicate()
	cause_chain.append(context.request.event_id)
	var child := RequestScript.new(
		"trigger.action",
		{
			"trigger_id": _definition.trigger_id,
			"action_id": _definition.action_id,
			"source_event_id": context.request.event_id,
			"cause_tags": cause_tags.duplicate(),
			"logical_tick": current_tick,
		},
		context.request.source_entity_id,
		context.request.target_entity_ids,
		"",
		context.request.depth + 1,
		cause_chain
	)
	_fire_count += 1
	_last_fire_tick = current_tick
	return ResultScript.enqueue_result([child])
