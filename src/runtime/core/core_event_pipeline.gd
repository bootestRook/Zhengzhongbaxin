class_name CoreEventPipeline
extends RefCounted

const RequestScript = preload("res://src/runtime/core/core_event_request.gd")
const ContextScript = preload("res://src/runtime/core/core_event_context.gd")
const HandlerResultScript = preload("res://src/runtime/core/core_event_handler_result.gd")
const PipelineResultScript = preload("res://src/runtime/core/core_event_pipeline_result.gd")
const TraceScript = preload("res://src/runtime/core/core_event_trace.gd")

const PHASES: Array[String] = ["gate", "modify", "resolve", "commit", "after"]

var max_depth: int = 16
var max_requests: int = 128
var _handlers: Dictionary = {}
var _committed_observers: Dictionary = {}
var _observer_depth: int = 0
var _trace: RefCounted = TraceScript.new()
var _next_registration_sequence: int = 1
var _next_event_sequence: int = 1


func _init(request_budget: int = 128, depth_budget: int = 16) -> void:
	max_requests = maxi(1, request_budget)
	max_depth = maxi(1, depth_budget)


func register(event_type: String, handler: RefCounted) -> String:
	if event_type.is_empty() or handler == null:
		return "invalid_handler_registration"
	for method_name: String in ["handler_id", "phase", "priority", "handle"]:
		if not handler.has_method(method_name):
			return "invalid_handler_contract"
	var handler_id: String = handler.handler_id()
	if handler_id.is_empty():
		return "handler_id_empty"
	var entries: Array = _handlers.get(event_type, [])
	for entry: Dictionary in entries:
		if entry.handler.handler_id() == handler_id:
			return "duplicate_handler_id"
	entries.append(
		{
			"handler": handler,
			"registration_sequence": _next_registration_sequence,
			"handle": "%s#%d" % [handler_id, _next_registration_sequence],
		}
	)
	_next_registration_sequence += 1
	_handlers[event_type] = entries
	return entries[-1].handle


func unregister(event_type: String, handle: String) -> String:
	var entries: Array = _handlers.get(event_type, [])
	for index in range(entries.size()):
		if entries[index].handle == handle:
			entries.remove_at(index)
			_handlers[event_type] = entries
			return ""
	return "unknown_handler_handle"


func register_committed_observer(observer: RefCounted) -> String:
	if observer == null or not observer.has_method("on_committed"):
		return "invalid_committed_observer"
	var handle := "observer#%d" % _next_registration_sequence
	_next_registration_sequence += 1
	_committed_observers[handle] = observer
	return handle


func unregister_committed_observer(handle: String) -> String:
	if not _committed_observers.has(handle):
		return "unknown_committed_observer"
	_committed_observers.erase(handle)
	return ""


func trace() -> Array[Dictionary]:
	return _trace.entries()


func trace_snapshot() -> Dictionary:
	return _trace.snapshot()


func restore_trace(snapshot: Dictionary) -> String:
	return _trace.restore(snapshot)


func dispatch(request: RefCounted, logical_tick: int = 0) -> RefCounted:
	if not (request is RequestScript):
		return PipelineResultScript.rejected("invalid_event_request", 0, [])
	if request.event_type.is_empty():
		return PipelineResultScript.rejected("event_type_empty", 0, [])
	var pending: Array[RefCounted] = [request]
	var committed_events: Array[RefCounted] = []
	var trace: Array[Dictionary] = []
	var processed := 0
	while not pending.is_empty():
		if processed >= max_requests:
			_trace.record(request, committed_events, trace, logical_tick, "event_budget_exceeded")
			return PipelineResultScript.rejected("event_budget_exceeded", processed, trace)
		var current: RefCounted = pending.pop_front()
		if current.depth > max_depth:
			_trace.record(request, committed_events, trace, logical_tick, "event_depth_exceeded")
			return PipelineResultScript.rejected("event_depth_exceeded", processed, trace)
		if current.event_id.is_empty():
			current.event_id = "event#%d" % _next_event_sequence
			_next_event_sequence += 1
		var context := ContextScript.new(current, current.payload)
		context.logical_tick = logical_tick
		var handlers: Array = _sorted_snapshot(String(current.event_type))
		var rejected_code := _dispatch_one(current, context, handlers, pending, committed_events, logical_tick)
		trace.append_array(context.trace)
		processed += 1
		if not rejected_code.is_empty():
			_trace.record(request, committed_events, trace, logical_tick, rejected_code)
			return PipelineResultScript.rejected(rejected_code, processed, trace)
	var observer_error := _notify_committed_observers(committed_events, logical_tick)
	if not observer_error.is_empty():
		_trace.record(request, committed_events, trace, logical_tick, observer_error)
		return PipelineResultScript.rejected(observer_error, processed, trace)
	_trace.record(request, committed_events, trace, logical_tick)
	return PipelineResultScript.success(committed_events, processed, trace)


func _notify_committed_observers(events: Array[RefCounted], logical_tick: int) -> String:
	if _observer_depth >= max_depth:
		return "event_observer_depth_exceeded"
	_observer_depth += 1
	for handle: String in _committed_observers:
		var observer: RefCounted = _committed_observers[handle]
		var observer_error: String = observer.on_committed(events, logical_tick)
		if not observer_error.is_empty():
			_observer_depth -= 1
			return observer_error
	_observer_depth -= 1
	return ""


func _dispatch_one(
	request: RefCounted,
	context: RefCounted,
	handlers: Array,
	pending: Array[RefCounted],
	committed_events: Array[RefCounted],
	logical_tick: int
) -> String:
	for phase: String in PHASES:
		context.phase = phase
		for entry: Dictionary in handlers:
			var handler: RefCounted = entry.handler
			if String(handler.phase()) != phase:
				continue
			var result = handler.handle(context)
			if not (result is HandlerResultScript):
				return "invalid_handler_result"
			context.trace_handler(handler.handler_id(), int(handler.priority()), result.kind)
			match result.kind:
				HandlerResultScript.CONTINUE:
					pass
				HandlerResultScript.REPLACE:
					if phase != "modify":
						return "replace_outside_modify"
					context.relay = result.relay.duplicate(true)
				HandlerResultScript.REJECT:
					return result.error_code if not result.error_code.is_empty() else "event_rejected"
				HandlerResultScript.COMMIT:
					if phase != "commit":
						return "commit_outside_commit_phase"
					for fact: RefCounted in result.facts:
						if not (fact is CoreDomainEvent):
							return "invalid_domain_event"
						fact.event_id = "%s#fact#%d" % [request.event_id, _next_event_sequence]
						fact.sequence = _next_event_sequence
						fact.logical_tick = logical_tick
						if fact.source_entity_id.is_empty():
							fact.source_entity_id = request.source_entity_id
						if fact.target_entity_ids.is_empty():
							fact.target_entity_ids = request.target_entity_ids.duplicate()
						fact.cause_chain = request.cause_chain.duplicate()
						_next_event_sequence += 1
						committed_events.append(fact)
				HandlerResultScript.ENQUEUE:
					if phase != "after":
						return "enqueue_outside_after_phase"
					for child_request: RefCounted in result.requests:
						if not (child_request is RequestScript):
							return "invalid_child_request"
						pending.append(child_request)
				_:
					return "unknown_handler_result"
	return ""


func _sorted_snapshot(event_type: String) -> Array:
	var snapshot: Array = (_handlers.get(event_type, []) as Array).duplicate()
	snapshot.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_handler: RefCounted = left.handler
		var right_handler: RefCounted = right.handler
		if int(left_handler.priority()) != int(right_handler.priority()):
			return int(left_handler.priority()) > int(right_handler.priority())
		if int(left_handler.scope_rank()) != int(right_handler.scope_rank()):
			return int(left_handler.scope_rank()) < int(right_handler.scope_rank())
		if int(left_handler.owner_sequence()) != int(right_handler.owner_sequence()):
			return int(left_handler.owner_sequence()) < int(right_handler.owner_sequence())
		if int(left.registration_sequence) != int(right.registration_sequence):
			return int(left.registration_sequence) < int(right.registration_sequence)
		return String(left_handler.handler_id()) < String(right_handler.handler_id())
	)
	return snapshot
