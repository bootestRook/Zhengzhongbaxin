class_name AbilityRunSubgraphOps
extends RefCounted

const ActionResultScript = preload("res://src/runtime/action_result.gd")


static func execute(run: RefCounted, operation: RefCounted, context: RefCounted) -> String:
	if run._subgraph_catalog == null or not run._subgraph_catalog.has_method("plan"):
		return "subgraph_catalog_missing"
	if run._subgraph_child != null:
		return "subgraph_child_already_active"
	var graph_id := String(operation.parameters.get("graph_id", ""))
	var child_plan: RefCounted = run._subgraph_catalog.plan(graph_id)
	if child_plan == null:
		return "unknown_subgraph"
	var run_script: Script = run.get_script()
	var child: RefCounted = run_script.new(
		child_plan,
		run._action_registry,
		run._action_executor,
		"%s::subgraph::%s" % [run.run_id, graph_id],
		run._condition_registry,
		run._subgraph_catalog
	)
	var result = child.execute(context)
	if not result.accepted:
		return "subgraph_failed:%s" % result.error_code
	if child.state == run.STATE_WAITING:
		var owner_scope: String = run.current_scope_id()
		child.set("scope_stack", [owner_scope])
		child.set("wait_scope_id", owner_scope)
		run._subgraph_child = child
		run.waiting_reason = "subgraph"
		run.resume_tick = child.resume_tick
		run.waiting_event_type = child.waiting_event_type
		run.waiting_filter = child.waiting_filter.duplicate(true)
		run.wait_scope_id = owner_scope
		run.state = run.STATE_WAITING
	return ""


static func tick(run: RefCounted, logical_tick: int):
	var child: RefCounted = run._subgraph_child
	if child == null:
		return ActionResultScript.rejected("subgraph_child_missing")
	var result = child.tick(logical_tick)
	return _resume_parent(run, result)


static func resume_event(run: RefCounted, event: RefCounted):
	var child: RefCounted = run._subgraph_child
	if child == null:
		return ActionResultScript.rejected("subgraph_child_missing")
	var result = child.resume_event(event)
	return _resume_parent(run, result)


static func cancel(run: RefCounted, reason: String) -> void:
	if run._subgraph_child != null:
		run._subgraph_child.cancel(reason)
		run._subgraph_child = null


static func clear(run: RefCounted) -> void:
	run._subgraph_child = null


static func bind_context(run: RefCounted) -> void:
	if run._subgraph_child == null:
		return
	run._subgraph_child.set("_context", run._context)
	bind_context(run._subgraph_child)


static func snapshot(run: RefCounted) -> Dictionary:
	if run._subgraph_child == null:
		return {}
	return {
		"graph_id": run._subgraph_child._plan.graph_id(),
		"state": run._subgraph_child.save_state(),
	}


static func restore(run: RefCounted, snapshot_data: Dictionary) -> String:
	run._subgraph_child = null
	if snapshot_data.is_empty():
		return ""
	if run._subgraph_catalog == null or not run._subgraph_catalog.has_method("plan"):
		return "subgraph_catalog_missing"
	var graph_id := String(snapshot_data.get("graph_id", ""))
	var child_plan: RefCounted = run._subgraph_catalog.plan(graph_id)
	if child_plan == null:
		return "unknown_subgraph"
	var run_script: Script = run.get_script()
	var child: RefCounted = run_script.new(
		child_plan,
		run._action_registry,
		run._action_executor,
		"%s::subgraph::%s" % [run.run_id, graph_id],
		run._condition_registry,
		run._subgraph_catalog
	)
	var restore_error: String = child.restore_state(snapshot_data.get("state", {}))
	if not restore_error.is_empty():
		return restore_error
	run._subgraph_child = child
	return ""


static func _resume_parent(run: RefCounted, result: RefCounted):
	var child: RefCounted = run._subgraph_child
	if child == null:
		return ActionResultScript.rejected("subgraph_child_missing")
	if child.state == run.STATE_WAITING:
		run.resume_tick = child.resume_tick
		run.waiting_event_type = child.waiting_event_type
		run.waiting_filter = child.waiting_filter.duplicate(true)
		run.state = run.STATE_WAITING
		return result
	run._subgraph_child = null
	run._clear_wait()
	if child.state == run.STATE_FAILED or child.state == run.STATE_CANCELLED:
		return run._fail("subgraph_failed:%s" % child.last_error_code)
	var operation: RefCounted = run._plan.get_operation(run.current_node_id)
	var advance_error: String = run._advance(operation)
	if not advance_error.is_empty():
		return run._fail(advance_error)
	return run._run_until_blocked(run._context)
