class_name AbilityServiceSnapshotCodec
extends RefCounted

const RunScript = preload("res://src/runtime/ability/ability_run.gd")
const SubgraphOpsScript = preload("res://src/runtime/ability/ability_run_subgraph_ops.gd")


static func encode(service: RefCounted) -> Dictionary:
	var active: Array[Dictionary] = []
	for run_id: String in service.active_run_ids():
		var entry: Dictionary = service._active_runs[run_id]
		var run: RefCounted = entry.run
		active.append(
			{
				"run_id": run_id,
				"entity_id": entry.entity_id,
				"grant_handle": entry.grant_handle,
				"ability_id": entry.get("ability_id", ""),
				"sequence": entry.sequence,
				"run": run.save_state(),
			}
		)
	return {"version": 1, "run_sequence": service._run_sequence, "active_runs": active}


static func decode(service: RefCounted, snapshot: Dictionary, contexts: Dictionary) -> String:
	if int(snapshot.get("version", 0)) != 1:
		return "ability_service_snapshot_version_invalid"
	for run_id: String in service.active_run_ids():
		service._active_runs.erase(run_id)
		if service._debug_registry != null and service._debug_registry.has_method("unregister_run"):
			service._debug_registry.unregister_run(run_id)
	service._run_sequence = int(snapshot.get("run_sequence", 1))
	for entry: Dictionary in snapshot.get("active_runs", []):
		var ability_id := String(entry.get("ability_id", ""))
		var entity_id := String(entry.get("entity_id", ""))
		var grant_handle := String(entry.get("grant_handle", ""))
		var plan: RefCounted = service._plans.get(ability_id)
		var entity: RefCounted = service._state.entity(entity_id)
		if plan == null or entity == null or not entity.abilities.has(grant_handle):
			return "ability_service_run_reference_invalid"
		if entity.abilities.ability_id(grant_handle) != ability_id:
			return "ability_service_grant_mismatch"
		var run := RunScript.new(plan, service._action_registry, service._action_executor, String(entry.get("run_id", "")), null, service._subgraph_catalog)
		var restore_error: String = run.restore_state(entry.get("run", {}))
		if not restore_error.is_empty():
			return restore_error
		if contexts.has(run.run_id):
			run._context = contexts[run.run_id]
			SubgraphOpsScript.bind_context(run)
		service._active_runs[run.run_id] = {
			"run": run,
			"entity_id": entity_id,
			"grant_handle": grant_handle,
			"ability_id": ability_id,
			"sequence": int(entry.get("sequence", 0)),
		}
		if service._debug_registry != null and service._debug_registry.has_method("register_run"):
			service._debug_registry.register_run(run, entity_id)
	return ""
