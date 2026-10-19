class_name AbilityRunScopeOps
extends RefCounted

const SubgraphOpsScript = preload("res://src/runtime/ability/ability_run_subgraph_ops.gd")


static func current(run: RefCounted) -> String:
	return run.scope_stack[-1] if not run.scope_stack.is_empty() else "run"


static func open(run: RefCounted, scope_id: String = "") -> String:
	var resolved_id := scope_id if not scope_id.is_empty() else "%s::scope#%d" % [run.run_id, run._scope_sequence]
	run._scope_sequence += 1
	if run.scope_stack.has(resolved_id):
		return ""
	run.scope_stack.append(resolved_id)
	return resolved_id


static func cancel(run: RefCounted, scope_id: String, reason: String) -> String:
	if scope_id.is_empty() or not run.scope_stack.has(scope_id):
		return "unknown_cancel_scope"
	if run.wait_scope_id == scope_id:
		SubgraphOpsScript.cancel(run, reason)
		run._clear_wait()
	run.scope_stack.erase(scope_id)
	if run.scope_stack.is_empty():
		run.state = run.STATE_CANCELLED
		run.last_error_code = reason
	return ""
