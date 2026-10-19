class_name ActionExecutor
extends RefCounted

const ActionResultScript = preload("res://src/runtime/action_result.gd")
const DomainEventScript = preload("res://src/runtime/core/core_domain_event.gd")

var _active_depth: int = 0
var _max_depth: int = 16
var _trace_limit: int = 200
var _trace: Array = []


func _init(trace_limit: int = 200, max_depth: int = 16) -> void:
	_trace_limit = maxi(1, trace_limit)
	_max_depth = maxi(1, max_depth)


func execute(action: RefCounted, context: RefCounted, action_arguments: Array = []):
	if _active_depth >= _max_depth:
		return ActionResultScript.rejected("action_depth_exceeded")
	if not action.has_method("validate") or not action.has_method("execute"):
		return ActionResultScript.rejected("invalid_action_contract")
	var validation_error: String = action.validate(context)
	if not validation_error.is_empty():
		_record(action, false, validation_error, [])
		return ActionResultScript.rejected(validation_error)

	var atomic := true
	if action.has_method("atomicity"):
		atomic = action.atomicity() == "atomic"
	var snapshot: Dictionary = context.snapshot_state() if atomic else {}
	_active_depth += 1
	var result = action.execute(context, action_arguments[0]) if action_arguments.size() == 1 else action.execute(context)
	_active_depth -= 1
	if not (result is ActionResultScript):
		if atomic:
			context.restore_state(snapshot)
		_record(action, false, "invalid_action_result", [])
		return ActionResultScript.rejected("invalid_action_result")
	if not result.accepted and atomic:
		var restore_error: String = context.restore_state(snapshot)
		if not restore_error.is_empty():
			result = ActionResultScript.rejected("rollback_failed:%s" % restore_error)
	_record(action, result.accepted, result.error_code, result.events)
	return result


func trace() -> Array:
	return _trace.duplicate(true)


func _record(action: RefCounted, accepted: bool, error_code: String, events: Array) -> void:
	var event_types: Array[String] = []
	for event in events:
		if event is Dictionary:
			event_types.append(String(event.get("type", "unknown")))
		elif event is DomainEventScript:
			event_types.append(event.event_type)
		else:
			event_types.append("unknown")
	_trace.append(
		{
			"action": action.action_id() if action.has_method("action_id") else action.get_script().resource_path,
			"accepted": accepted,
			"error_code": error_code,
			"event_types": event_types,
		}
	)
	while _trace.size() > _trace_limit:
		_trace.pop_front()
