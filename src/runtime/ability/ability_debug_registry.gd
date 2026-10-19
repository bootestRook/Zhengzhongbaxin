class_name AbilityDebugRegistry
extends RefCounted

const SnapshotScript = preload("res://src/runtime/ability/ability_execution_snapshot.gd")

var _runs: Dictionary = {}
var _next_sequence: int = 1
var _selected_run_id: String = ""
var _event_trace_provider: RefCounted


func register_run(run: RefCounted, owner_entity_id: String = "") -> String:
	if run == null or not run.has_method("execution_snapshot"):
		return "invalid_ability_run"
	var run_id: String = String(run.run_id)
	if run_id.is_empty() or _runs.has(run_id):
		return "duplicate_ability_run_id"
	_runs[run_id] = {"run": run, "owner_entity_id": owner_entity_id, "sequence": _next_sequence}
	_next_sequence += 1
	return ""


func unregister_run(run_id: String) -> String:
	if not _runs.has(run_id):
		return "unknown_ability_run"
	_runs.erase(run_id)
	if _selected_run_id == run_id:
		_selected_run_id = ""
	return ""


func select_run(run_id: String) -> String:
	if not _runs.has(run_id):
		return "unknown_ability_run"
	_selected_run_id = run_id
	return ""


func selected_run_id() -> String:
	return _selected_run_id


func set_event_trace_provider(provider: RefCounted) -> void:
	_event_trace_provider = provider


func snapshot(run_id: String, logical_tick: int) -> RefCounted:
	var entry: Dictionary = _runs.get(run_id, {})
	if entry.is_empty():
		return null
	var raw: Dictionary = entry.run.execution_snapshot()
	var snapshot := SnapshotScript.new()
	snapshot.run_id = String(raw.get("run_id", run_id))
	snapshot.graph_id = String(raw.get("graph_id", ""))
	snapshot.owner_entity_id = String(entry.owner_entity_id)
	snapshot.state = String(raw.get("state", ""))
	snapshot.current_node_id = String(raw.get("current_node_id", ""))
	snapshot.logical_tick = logical_tick
	snapshot.sequence = int(entry.sequence)
	snapshot.last_error_code = String(raw.get("last_error_code", ""))
	snapshot.waiting_reason = String(raw.get("waiting_reason", ""))
	snapshot.resume_tick = int(raw.get("resume_tick", -1))
	snapshot.waiting_event_type = String(raw.get("waiting_event_type", ""))
	snapshot.waiting_filter = raw.get("waiting_filter", {}).duplicate(true)
	snapshot.wait_scope_id = String(raw.get("wait_scope_id", ""))
	snapshot.scope_stack.assign(raw.get("scope_stack", []))
	snapshot.active_edge = raw.get("active_edge", {}).duplicate(true)
	snapshot.trace = raw.get("trace", []).duplicate(true)
	if _event_trace_provider != null and _event_trace_provider.has_method("trace"):
		snapshot.event_trace = _event_trace_provider.trace()
	var visited: Variant = raw.get("visited_node_ids", [])
	if typeof(visited) == TYPE_ARRAY:
		snapshot.visited_node_ids.assign(visited)
	snapshot.enter_counts = raw.get("enter_counts", {}).duplicate(true)
	snapshot.values = raw.get("values", {}).duplicate(true)
	return snapshot


func publish_selected(logical_tick: int) -> void:
	if _selected_run_id.is_empty() or not EngineDebugger.is_active():
		return
	var snapshot_value: RefCounted = snapshot(_selected_run_id, logical_tick)
	if snapshot_value == null:
		return
	EngineDebugger.send_message("combat_ability/snapshot", [snapshot_value.to_dictionary()])
