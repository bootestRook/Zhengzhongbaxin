class_name AbilityRun
extends RefCounted
const ActionResultScript = preload("res://src/runtime/action_result.gd")
const DomainEventScript = preload("res://src/runtime/core/core_domain_event.gd")
const SnapshotCodecScript = preload("res://src/runtime/ability/ability_run_snapshot_codec.gd")
const DataOpsScript = preload("res://src/runtime/ability/ability_run_data_ops.gd")
const ScopeOpsScript = preload("res://src/runtime/ability/ability_run_scope_ops.gd")
const TraceOpsScript = preload("res://src/runtime/ability/ability_run_trace_ops.gd")
const WaitOpsScript = preload("res://src/runtime/ability/ability_run_wait_ops.gd")
const SubgraphOpsScript = preload("res://src/runtime/ability/ability_run_subgraph_ops.gd")
const STATE_READY := "ready"
const STATE_RUNNING := "running"
const STATE_WAITING := "waiting"
const STATE_ENDED := "ended"
const STATE_FAILED := "failed"
const STATE_CANCELLED := "cancelled"
var run_id: String = ""
var state: String = STATE_READY
var current_node_id: String = ""
var last_error_code: String = ""
var waiting_reason: String = ""
var resume_tick: int = -1
var waiting_event_type: String = ""
var waiting_filter: Dictionary = {}
var wait_scope_id: String = ""
var visited_node_ids: Array[String] = []
var enter_counts: Dictionary = {}
var scope_stack: Array[String] = []
var active_edge: Dictionary = {}
var trace: Array[Dictionary] = []
var _plan: RefCounted
var _action_registry: RefCounted
var _action_executor: RefCounted
var _condition_registry: RefCounted
var _subgraph_catalog: RefCounted
var _subgraph_child: RefCounted
var _context: RefCounted
var _values: Dictionary = {}
var _repeat_counts: Dictionary = {}
var _scope_sequence: int = 1
func _init(
	execution_plan: RefCounted = null,
	action_registry: RefCounted = null,
	action_executor: RefCounted = null,
	instance_run_id: String = "",
	condition_registry: RefCounted = null,
	subgraph_catalog: RefCounted = null
) -> void:
	_plan = execution_plan
	_action_registry = action_registry
	_action_executor = action_executor
	_condition_registry = condition_registry
	_subgraph_catalog = subgraph_catalog
	run_id = instance_run_id
func action_id() -> String:
	return "combat.ability.run"
func atomicity() -> String:
	return "atomic"
func validate(_context_value: RefCounted) -> String:
	if state != STATE_READY:
		return "ability_run_not_ready"
	if _plan == null or not _plan.has_method("get_operation"):
		return "ability_plan_missing"
	if _action_registry == null or not _action_registry.has_method("build_action"):
		return "ability_action_registry_missing"
	if _action_executor == null or not _action_executor.has_method("execute"):
		return "ability_action_executor_missing"
	return ""
func execute(context: RefCounted, selected_entry_node_id: String = ""):
	_context = context
	_values = _plan.default_values() if _plan.has_method("default_values") else {}
	_repeat_counts.clear()
	visited_node_ids.clear()
	enter_counts.clear()
	waiting_reason = ""
	resume_tick = -1
	waiting_event_type = ""
	waiting_filter.clear()
	wait_scope_id = ""
	scope_stack = ["run"]
	_scope_sequence = 1
	_subgraph_child = null
	TraceOpsScript.clear(self)
	current_node_id = selected_entry_node_id if not selected_entry_node_id.is_empty() else _plan.entry_node_id()
	return _run_until_blocked(context)
func tick(logical_tick: int):
	return WaitOpsScript.tick(self, logical_tick)
func resume_event(event: RefCounted):
	return WaitOpsScript.resume_event(self, event)
func cancel(reason: String = "ability_cancelled") -> RefCounted:
	if state == STATE_ENDED or state == STATE_FAILED or state == STATE_CANCELLED:
		return ActionResultScript.rejected("ability_run_finished")
	state = STATE_CANCELLED
	last_error_code = reason
	SubgraphOpsScript.cancel(self, reason)
	_clear_wait()
	return ActionResultScript.rejected(reason)
func current_scope_id() -> String:
	return ScopeOpsScript.current(self)
func open_cancel_scope(scope_id: String = "") -> String:
	return ScopeOpsScript.open(self, scope_id)
func cancel_scope(scope_id: String, reason: String = "ability_scope_cancelled") -> String:
	return ScopeOpsScript.cancel(self, scope_id, reason)
func execution_snapshot() -> Dictionary:
	return SnapshotCodecScript.runtime(self)

func save_state() -> Dictionary:
	return SnapshotCodecScript.encode(self)

func restore_state(snapshot: Dictionary) -> String:
	return SnapshotCodecScript.decode(self, snapshot)
func _run_until_blocked(context: RefCounted):
	state = STATE_RUNNING
	var emitted_events: Array = []
	var remaining_steps: int = _plan.operation_count() + 1 + _repeat_budget()
	while remaining_steps > 0:
		remaining_steps -= 1
		var operation: RefCounted = _plan.get_operation(current_node_id)
		if operation == null:
			return _fail("plan_operation_missing")
		visited_node_ids.append(current_node_id)
		enter_counts[current_node_id] = int(enter_counts.get(current_node_id, 0)) + 1
		match operation.kind:
			"entry", "sequence":
				var advance_error := _advance(operation)
				if not advance_error.is_empty():
					return _fail(advance_error)
			"action":
				var action_result = _execute_action(operation, context)
				if not action_result.accepted:
					last_error_code = action_result.error_code
					return _fail("ability_action_failed")
				DataOpsScript.capture_action_outputs(self, operation, context)
				emitted_events.append_array(action_result.events)
				var action_error := _advance(operation)
				if not action_error.is_empty():
					return _fail(action_error)
			"branch":
				var branch_pin := "true" if _evaluate_condition(operation, context) else "false"
				var branch_error := _advance(operation, branch_pin)
				if not branch_error.is_empty():
					return _fail(branch_error)
			"value":
				var value_error := DataOpsScript.evaluate_value(self, operation, context)
				if not value_error.is_empty():
					return _fail(value_error)
				var value_advance_error := _advance(operation, "then")
				if not value_advance_error.is_empty():
					return _fail(value_advance_error)
			"variable_set":
				var variable_error := DataOpsScript.write_variable(self, operation)
				if not variable_error.is_empty():
					return _fail(variable_error)
				var variable_advance_error := _advance(operation)
				if not variable_advance_error.is_empty():
					return _fail(variable_advance_error)
			"subgraph":
				var subgraph_error: String = SubgraphOpsScript.execute(self, operation, context)
				if not subgraph_error.is_empty():
					return _fail(subgraph_error)
				if state == STATE_WAITING:
					return ActionResultScript.success(emitted_events)
				var subgraph_advance_error := _advance(operation)
				if not subgraph_advance_error.is_empty():
					return _fail(subgraph_advance_error)
			"delay":
				var duration := int(operation.parameters.get("duration_ticks", 0))
				if duration < 0:
					return _fail("delay_duration_invalid")
				if duration == 0:
					var zero_delay_error := _advance(operation)
					if not zero_delay_error.is_empty():
						return _fail(zero_delay_error)
					continue
				state = STATE_WAITING
				waiting_reason = "tick"
				wait_scope_id = current_scope_id()
				resume_tick = int(context.logical_tick) + duration
				return ActionResultScript.success(emitted_events)
			"wait":
				waiting_event_type = String(operation.parameters.get("event_type", ""))
				if waiting_event_type.is_empty():
					return _fail("wait_event_type_empty")
				state = STATE_WAITING
				waiting_reason = "event"
				wait_scope_id = current_scope_id()
				waiting_filter = operation.parameters.get("filter", {}).duplicate(true)
				var timeout_ticks := int(operation.parameters.get("timeout_ticks", 0))
				resume_tick = int(context.logical_tick) + timeout_ticks if timeout_ticks > 0 else -1
				return ActionResultScript.success(emitted_events)
			"repeat":
				var count := int(_repeat_counts.get(operation.node_id, operation.parameters.get("count", 0)))
				if count < 0 or count > 64:
					return _fail("repeat_bound_invalid")
				if count > 0:
					_repeat_counts[operation.node_id] = count - 1
					var body_error := _advance(operation, "body")
					if not body_error.is_empty():
						return _fail(body_error)
				else:
					_repeat_counts.erase(operation.node_id)
					var done_error := _advance(operation, "done")
					if not done_error.is_empty():
						return _fail(done_error)
			"end":
				state = STATE_ENDED
				return ActionResultScript.success(emitted_events)
			_:
				return _fail("unknown_plan_operation")
	return _fail("ability_step_budget_exceeded")
func _execute_action(operation: RefCounted, context: RefCounted):
	var action: RefCounted = _action_registry.build_action(operation.action_id)
	if action == null:
		return ActionResultScript.rejected("ability_action_missing")
	if action.has_method("configure"):
		action.configure(DataOpsScript.resolved_parameters(self, operation))
	var action_result = _action_executor.execute(action, context)
	if not (action_result is ActionResultScript):
		return ActionResultScript.rejected("invalid_ability_action_result")
	return action_result

func _repeat_budget() -> int:
	var budget := 0
	for node_id: String in _plan.operation_order():
		var operation: RefCounted = _plan.get_operation(node_id)
		if operation != null and operation.kind == "repeat":
			budget += maxi(1, int(operation.parameters.get("count", 0))) * 2
	return budget
func _evaluate_condition(operation: RefCounted, context: RefCounted) -> bool:
	var source_route: String = _plan.get_input_source(operation.node_id, "condition")
	if not source_route.is_empty() and _values.has(source_route):
		return bool(_values[source_route])
	if operation.parameters.has("condition"):
		return bool(operation.parameters.condition)
	var condition_id := String(operation.parameters.get("condition_id", ""))
	if not condition_id.is_empty() and _condition_registry != null:
		var result = _condition_registry.evaluate(condition_id, context, operation.parameters)
		return bool(result.passed) if result != null else false
	return false
func _advance(operation: RefCounted, output_pin: String = "") -> String:
	var selected_pin: String = output_pin if not output_pin.is_empty() else operation.default_output_pin
	var next_node_id: String = _plan.get_next_node(operation.node_id, selected_pin)
	if next_node_id.is_empty():
		return "plan_route_missing"
	current_node_id = next_node_id
	TraceOpsScript.record_edge(self, operation, selected_pin, next_node_id)
	return ""
func _clear_wait() -> void:
	SubgraphOpsScript.clear(self)
	waiting_reason = ""
	resume_tick = -1
	waiting_event_type = ""
	waiting_filter.clear()
	wait_scope_id = ""
func _fail(error_code: String):
	state = STATE_FAILED
	_clear_wait()
	if last_error_code.is_empty():
		last_error_code = error_code
	return ActionResultScript.rejected(error_code)
