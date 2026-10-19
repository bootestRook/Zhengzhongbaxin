class_name AbilityRunWaitOps
extends RefCounted

const ActionResultScript = preload("res://src/runtime/action_result.gd")
const DomainEventScript = preload("res://src/runtime/core/core_domain_event.gd")
const SubgraphOpsScript = preload("res://src/runtime/ability/ability_run_subgraph_ops.gd")


static func tick(run: RefCounted, logical_tick: int):
	if run.state != run.STATE_WAITING:
		return ActionResultScript.rejected("ability_not_waiting")
	if run.waiting_reason == "subgraph":
		return SubgraphOpsScript.tick(run, logical_tick)
	if run.waiting_reason == "event":
		if run.resume_tick < 0 or logical_tick < run.resume_tick:
			return ActionResultScript.rejected("ability_wait_not_ready")
		var timeout_operation: RefCounted = run._plan.get_operation(run.current_node_id)
		run._clear_wait()
		var timeout_error: String = run._advance(timeout_operation, "timeout")
		if not timeout_error.is_empty():
			return run._fail("ability_wait_timeout_route_missing")
		return run._run_until_blocked(run._context)
	if run.waiting_reason != "tick" or logical_tick < run.resume_tick:
		return ActionResultScript.rejected("ability_wait_not_ready")
	run._clear_wait()
	var operation: RefCounted = run._plan.get_operation(run.current_node_id)
	var advance_error: String = run._advance(operation)
	if not advance_error.is_empty():
		return run._fail(advance_error)
	return run._run_until_blocked(run._context)


static func resume_event(run: RefCounted, event: RefCounted):
	if run.state != run.STATE_WAITING or run.waiting_reason != "event":
		if run.state == run.STATE_WAITING and run.waiting_reason == "subgraph":
			return SubgraphOpsScript.resume_event(run, event)
		return ActionResultScript.rejected("ability_not_waiting_event")
	if not (event is DomainEventScript) or String(event.event_type) != run.waiting_event_type:
		return ActionResultScript.rejected("ability_event_not_matched")
	for key: String in run.waiting_filter:
		if event.payload.get(key, null) != run.waiting_filter[key]:
			return ActionResultScript.rejected("ability_event_filter_not_matched")
	if run._context != null and run._context.has_method("set_event"):
		run._context.set_event(event)
	run._clear_wait()
	var operation: RefCounted = run._plan.get_operation(run.current_node_id)
	var advance_error: String = run._advance(operation, "resumed")
	if not advance_error.is_empty():
		return run._fail(advance_error)
	return run._run_until_blocked(run._context)
