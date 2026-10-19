class_name AbilityRunSnapshotCodec
extends RefCounted

const SubgraphOpsScript = preload("res://src/runtime/ability/ability_run_subgraph_ops.gd")


static func encode(run: RefCounted) -> Dictionary:
	return {
		"version": 1,
		"run_id": run.run_id,
		"graph_id": run._plan.graph_id() if run._plan != null else "",
		"state": run.state,
		"current_node_id": run.current_node_id,
		"last_error_code": run.last_error_code,
		"waiting_reason": run.waiting_reason,
		"resume_tick": run.resume_tick,
		"waiting_event_type": run.waiting_event_type,
		"waiting_filter": run.waiting_filter.duplicate(true),
		"wait_scope_id": run.wait_scope_id,
		"scope_stack": run.scope_stack.duplicate(),
		"scope_sequence": run._scope_sequence,
		"active_edge": run.active_edge.duplicate(true),
		"trace": run.trace.duplicate(true),
		"visited_node_ids": run.visited_node_ids.duplicate(),
		"enter_counts": run.enter_counts.duplicate(true),
		"values": run._values.duplicate(true),
		"repeat_counts": run._repeat_counts.duplicate(true),
		"subgraph_child": SubgraphOpsScript.snapshot(run),
	}


static func runtime(run: RefCounted) -> Dictionary:
	var snapshot := encode(run)
	snapshot.erase("version")
	return snapshot


static func decode(run: RefCounted, snapshot: Dictionary) -> String:
	if int(snapshot.get("version", 0)) != 1:
		return "ability_run_snapshot_version_invalid"
	if run._plan == null or String(snapshot.get("graph_id", "")) != run._plan.graph_id():
		return "ability_run_plan_mismatch"
	run.run_id = String(snapshot.get("run_id", run.run_id))
	run.state = String(snapshot.get("state", run.STATE_READY))
	run.current_node_id = String(snapshot.get("current_node_id", ""))
	run.last_error_code = String(snapshot.get("last_error_code", ""))
	run.waiting_reason = String(snapshot.get("waiting_reason", ""))
	run.resume_tick = int(snapshot.get("resume_tick", -1))
	run.waiting_event_type = String(snapshot.get("waiting_event_type", ""))
	run.waiting_filter = snapshot.get("waiting_filter", {}).duplicate(true)
	run.wait_scope_id = String(snapshot.get("wait_scope_id", ""))
	run.scope_stack.assign(snapshot.get("scope_stack", ["run"]))
	run._scope_sequence = int(snapshot.get("scope_sequence", 1))
	run.active_edge = snapshot.get("active_edge", {}).duplicate(true)
	run.trace = snapshot.get("trace", []).duplicate(true)
	run.visited_node_ids.assign(snapshot.get("visited_node_ids", []))
	run.enter_counts = snapshot.get("enter_counts", {}).duplicate(true)
	run._values = snapshot.get("values", {}).duplicate(true)
	run._repeat_counts = snapshot.get("repeat_counts", {}).duplicate(true)
	return SubgraphOpsScript.restore(run, snapshot.get("subgraph_child", {}))
