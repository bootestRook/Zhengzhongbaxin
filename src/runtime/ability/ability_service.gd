class_name AbilityService
extends RefCounted

const ActionResultScript = preload("res://src/runtime/action_result.gd")
const DefinitionScript = preload("res://src/runtime/ability/ability_definition.gd")
const RunScript = preload("res://src/runtime/ability/ability_run.gd")
const DomainEventScript = preload("res://src/runtime/core/core_domain_event.gd")
const ExecutionContextScript = preload("res://src/runtime/core/core_execution_context.gd")
const SnapshotCodecScript = preload("res://src/runtime/ability/ability_service_snapshot_codec.gd")

var _state: RefCounted
var _action_registry: RefCounted
var _action_executor: RefCounted
var _definitions: Dictionary = {}
var _plans: Dictionary = {}
var _run_sequence: int = 1
var _active_runs: Dictionary = {}
var _debug_registry: RefCounted
var _pipeline: RefCounted
var _target_resolvers: RefCounted
var _subgraph_catalog: RefCounted
var _observer_handle: String = ""
func _init(
	state: RefCounted,
	action_registry: RefCounted,
	action_executor: RefCounted,
	debug_registry: RefCounted = null,
	event_pipeline: RefCounted = null,
	target_resolvers: RefCounted = null,
	subgraph_catalog: RefCounted = null
) -> void:
	_state = state
	_action_registry = action_registry
	_action_executor = action_executor
	_debug_registry = debug_registry
	_target_resolvers = target_resolvers
	_subgraph_catalog = subgraph_catalog
	if event_pipeline != null:
		attach_pipeline(event_pipeline)
func attach_pipeline(event_pipeline: RefCounted) -> String:
	if event_pipeline == null or not event_pipeline.has_method("register_committed_observer"):
		return "invalid_event_pipeline"
	if not _observer_handle.is_empty():
		return ""
	_pipeline = event_pipeline
	_observer_handle = _pipeline.register_committed_observer(self)
	if _debug_registry != null and _debug_registry.has_method("set_event_trace_provider"):
		_debug_registry.set_event_trace_provider(_pipeline)
	return "" if not _observer_handle.is_empty() else "ability_event_observer_registration_failed"
func detach_pipeline() -> String:
	if _pipeline == null or _observer_handle.is_empty():
		return "ability_event_observer_not_registered"
	var result: String = _pipeline.unregister_committed_observer(_observer_handle)
	if result.is_empty():
		_observer_handle = ""
		if _debug_registry != null and _debug_registry.has_method("set_event_trace_provider"):
			_debug_registry.set_event_trace_provider(null)
		_pipeline = null
	return result
func on_committed(events: Array[RefCounted], _logical_tick: int) -> String:
	for event: RefCounted in events:
		if not (event is DomainEventScript):
			return "invalid_domain_event"
		var source_id := String(event.source_entity_id)
		var targets: Array[String] = event.target_entity_ids.duplicate()
		var context := ExecutionContextScript.new(_state, _pipeline, source_id, targets, _target_resolvers)
		var results := trigger_event(event, context)
		for result: RefCounted in results:
			if not result.accepted:
				return result.error_code
	return ""
func register_definition(definition: RefCounted, plan: RefCounted) -> String:
	if not (definition is DefinitionScript) or plan == null:
		return "invalid_ability_definition"
	var validation_error: String = definition.validate()
	if not validation_error.is_empty():
		return validation_error
	if plan.graph_id() != definition.graph_id:
		return "ability_plan_graph_mismatch"
	if _definitions.has(definition.ability_id):
		return "duplicate_ability_id"
	_definitions[definition.ability_id] = definition
	_plans[definition.ability_id] = plan
	return ""
func grant(entity_id: String, ability_id: String, source_id: String = "") -> String:
	var entity: RefCounted = _state.entity(entity_id)
	if entity == null:
		return "unknown_entity"
	if not _definitions.has(ability_id):
		return "unknown_ability"
	return entity.abilities.grant(ability_id, source_id)
func revoke(entity_id: String, grant_handle: String) -> String:
	var entity: RefCounted = _state.entity(entity_id)
	if entity == null:
		return "unknown_entity"
	for run_id: String in active_run_ids():
		var entry: Dictionary = _active_runs.get(run_id, {})
		if String(entry.get("entity_id", "")) == entity_id and String(entry.get("grant_handle", "")) == grant_handle:
			cancel_run(run_id, "ability_grant_revoked")
	return entity.abilities.revoke(grant_handle)
func activate(entity_id: String, grant_handle: String, context: RefCounted) -> RefCounted:
	var entity: RefCounted = _state.entity(entity_id)
	if entity == null:
		return ActionResultScript.rejected("unknown_entity")
	var ability_id: String = entity.abilities.ability_id(grant_handle)
	if ability_id.is_empty() or not _definitions.has(ability_id):
		return ActionResultScript.rejected("ability_not_granted")
	var definition: RefCounted = _definitions[ability_id]
	if not entity.cooldowns.is_ready(grant_handle, _state.logical_tick):
		return ActionResultScript.rejected("ability_on_cooldown")
	var before_costs: Dictionary = {}
	for attribute_id: String in definition.costs:
		if not entity.attributes.has(attribute_id):
			return ActionResultScript.rejected("ability_cost_attribute_missing")
		var cost: float = float(definition.costs[attribute_id])
		if entity.attributes.value(attribute_id) < cost:
			return ActionResultScript.rejected("ability_cost_insufficient")
		before_costs[attribute_id] = entity.attributes.value(attribute_id)
	for attribute_id: String in definition.costs:
		var cost_error: String = entity.attributes.set_value(
			attribute_id, entity.attributes.value(attribute_id) - float(definition.costs[attribute_id])
		)
		if not cost_error.is_empty():
			_restore_costs(entity, before_costs)
			return ActionResultScript.rejected(cost_error)
	var run := RunScript.new(
		_plans[ability_id],
		_action_registry,
		_action_executor,
		"%s#%d" % [ability_id, _run_sequence],
		null,
		_subgraph_catalog
	)
	_run_sequence += 1
	var result = _action_executor.execute(run, context)
	if not result.accepted:
		_restore_costs(entity, before_costs)
		return result
	entity.cooldowns.start(grant_handle, _state.logical_tick, definition.cooldown_ticks)
	_active_runs[run.run_id] = {
		"run": run,
		"entity_id": entity_id,
		"grant_handle": grant_handle,
		"ability_id": ability_id,
		"sequence": _run_sequence - 1,
	}
	if _debug_registry != null and _debug_registry.has_method("register_run"):
		_debug_registry.register_run(run, entity_id)
	return result
func active_run_ids() -> Array[String]:
	var ids: Array[String] = []
	for run_id: String in _active_runs:
		ids.append(run_id)
	ids.sort()
	return ids
func snapshot() -> Dictionary:
	return SnapshotCodecScript.encode(self)
func restore(snapshot_data: Dictionary, contexts: Dictionary = {}) -> String:
	return SnapshotCodecScript.decode(self, snapshot_data, contexts)
func run(run_id: String) -> RefCounted:
	return _active_runs.get(run_id, {}).get("run")

func tick() -> Array[RefCounted]:
	var results: Array[RefCounted] = []
	var ids := active_run_ids()
	for run_id: String in ids:
		var active: RefCounted = run(run_id)
		if active == null:
			continue
		var result = active.tick(_state.logical_tick)
		results.append(result)
		_cleanup_finished_run(run_id, active)
	return results

func resume_event(event: RefCounted) -> Array[RefCounted]:
	var results: Array[RefCounted] = []
	for run_id: String in active_run_ids():
		var active: RefCounted = run(run_id)
		if active == null or not ["event", "subgraph"].has(active.waiting_reason):
			continue
		var result = active.resume_event(event)
		results.append(result)
		_cleanup_finished_run(run_id, active)
	return results


func trigger_event(event: RefCounted, context: RefCounted) -> Array[RefCounted]:
	var results: Array[RefCounted] = []
	if not (event is DomainEventScript):
		return [ActionResultScript.rejected("invalid_domain_event")]
	results.append_array(resume_event(event))
	if context == null:
		return results
	if context.has_method("set_event"):
		context.set_event(event)
	for entity: RefCounted in _state.entities_in_sequence_order():
		for grant_handle: String in entity.abilities.handles():
			var ability_id: String = entity.abilities.ability_id(grant_handle)
			var plan: RefCounted = _plans.get(ability_id)
			if plan == null or not plan.has_method("entry_node_ids"):
				continue
			for entry_node_id: String in plan.entry_node_ids(event.event_type):
				if not _event_entry_matches(plan, entry_node_id, event, entity.entity_id):
					continue
				var run := RunScript.new(plan, _action_registry, _action_executor, "%s#event#%d" % [ability_id, _run_sequence], null, _subgraph_catalog)
				_run_sequence += 1
				var result = _action_executor.execute(run, context, [entry_node_id])
				results.append(result)
				if result.accepted and run.state == RunScript.STATE_WAITING:
					_register_active_run(run, entity.entity_id, grant_handle, ability_id)
	return results


func cancel_run(run_id: String, reason: String = "ability_cancelled") -> String:
	var active: RefCounted = run(run_id)
	if active == null:
		return "unknown_ability_run"
	active.cancel(reason)
	_active_runs.erase(run_id)
	if _debug_registry != null and _debug_registry.has_method("unregister_run"):
		_debug_registry.unregister_run(run_id)
	return ""


func _cleanup_finished_run(run_id: String, active: RefCounted) -> void:
	if [RunScript.STATE_ENDED, RunScript.STATE_FAILED, RunScript.STATE_CANCELLED].has(active.state):
		_active_runs.erase(run_id)
		if _debug_registry != null and _debug_registry.has_method("unregister_run"):
			_debug_registry.unregister_run(run_id)


func _register_active_run(run: RefCounted, entity_id: String, grant_handle: String, ability_id: String) -> void:
	_active_runs[run.run_id] = {
		"run": run,
		"entity_id": entity_id,
		"grant_handle": grant_handle,
		"ability_id": ability_id,
		"sequence": _run_sequence - 1,
	}
	if _debug_registry != null and _debug_registry.has_method("register_run"):
		_debug_registry.register_run(run, entity_id)


func _event_entry_matches(plan: RefCounted, node_id: String, event: RefCounted, entity_id: String) -> bool:
	var operation: RefCounted = plan.get_operation(node_id)
	if operation == null:
		return false
	var scope := String(operation.parameters.get("scope", "source"))
	if scope == "any":
		return true
	if scope == "target":
		return event.target_entity_ids.has(entity_id)
	return event.source_entity_id.is_empty() or event.source_entity_id == entity_id


func _restore_costs(entity: RefCounted, before_costs: Dictionary) -> void:
	for attribute_id: String in before_costs:
		entity.attributes.set_value(attribute_id, float(before_costs[attribute_id]))
