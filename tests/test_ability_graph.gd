extends RefCounted

const ActionExecutorScript = preload("res://src/runtime/action_executor.gd")
const ActionResultScript = preload("res://src/runtime/action_result.gd")
const GraphDefinitionScript = preload(
	"res://src/runtime/ability/ability_graph_definition.gd"
)
const NodeDefinitionScript = preload(
	"res://src/runtime/ability/ability_graph_node_definition.gd"
)
const ConnectionDefinitionScript = preload(
	"res://src/runtime/ability/ability_graph_connection_definition.gd"
)
const ActionNodeConfigurationScript = preload(
	"res://src/runtime/ability/ability_action_node_configuration.gd"
)
const AbilityNodeConfigurationScript = preload(
	"res://src/runtime/ability/ability_node_configuration.gd"
)
const NodeRegistryScript = preload(
	"res://src/runtime/ability/ability_node_registry.gd"
)
const ActionRegistryScript = preload(
	"res://src/runtime/ability/ability_action_registry.gd"
)
const GraphCompilerScript = preload(
	"res://src/runtime/ability/ability_graph_compiler.gd"
)
const AbilityRunScript = preload(
	"res://src/runtime/ability/ability_run.gd"
)
const AbilityDebugRegistryScript = preload(
	"res://src/runtime/ability/ability_debug_registry.gd"
)
const AbilityDefinitionScript = preload("res://src/runtime/ability/ability_definition.gd")
const AbilityServiceScript = preload("res://src/runtime/ability/ability_service.gd")
const AbilityPlanCatalogScript = preload("res://src/runtime/ability/ability_plan_catalog.gd")
const AttributeDefinitionScript = preload("res://src/runtime/core/core_attribute_definition.gd")
const CoreStateScript = preload("res://src/runtime/core/core_state.gd")
const GraphResourceScript = preload("res://src/runtime/ability/ability_graph_resource.gd")
const NodeResourceScript = preload("res://src/runtime/ability/ability_graph_node_resource.gd")
const ConnectionResourceScript = preload(
	"res://src/runtime/ability/ability_graph_connection_resource.gd"
)
const DocumentControllerScript = preload(
	"res://addons/combat_framework_editor/editor/ability_graph_document_controller.gd"
)
const ExecutionContextScript = preload("res://src/runtime/core/core_execution_context.gd")
const TargetRegistryScript = preload("res://src/runtime/core/core_target_resolver_registry.gd")
const TargetActionResolverScript = preload("res://src/runtime/ability/ability_target_action_resolver.gd")
const DamageModuleScript = preload("res://src/runtime/modules/damage/damage_module.gd")
const DomainEventScript = preload("res://src/runtime/core/core_domain_event.gd")
const EventRequestScript = preload("res://src/runtime/core/core_event_request.gd")
const EventHandlerResultScript = preload("res://src/runtime/core/core_event_handler_result.gd")
const EventPipelineScript = preload("res://src/runtime/core/core_event_pipeline.gd")
const NodeDescriptorScript = preload("res://src/runtime/ability/ability_node_descriptor.gd")
const ExtensionManifestScript = preload("res://src/runtime/ability/ability_extension_manifest.gd")
const FrameworkRegistryScript = preload("res://src/runtime/ability/ability_framework_registry.gd")
const SubgraphReferenceScript = preload("res://src/runtime/ability/ability_subgraph_reference.gd")
const SubgraphCatalogScript = preload("res://src/runtime/ability/ability_subgraph_catalog.gd")
const GraphVariableScript = preload(
	"res://src/runtime/ability/ability_graph_variable_definition.gd"
)


class FakeCombatContext extends RefCounted:
	var value: int = 10

	func snapshot_state() -> Dictionary:
		return {"value": value}

	func restore_state(snapshot: Dictionary) -> String:
		value = int(snapshot.value)
		return ""


class AbilityTestIncrementAction extends RefCounted:
	func action_id() -> String:
		return "test.increment"

	func atomicity() -> String:
		return "atomic"

	func validate(_context: RefCounted) -> String:
		return ""

	func execute(context: RefCounted):
		context.value += 5
		return ActionResultScript.success([{"type": "test.incremented", "amount": 5}])


class AbilityTestRejectAction extends RefCounted:
	func action_id() -> String:
		return "test.reject"

	func atomicity() -> String:
		return "atomic"

	func validate(_context: RefCounted) -> String:
		return ""

	func execute(context: RefCounted):
		context.value += 100
		return ActionResultScript.rejected("forced_failure")


class AbilityTestMarkEventAction extends RefCounted:
	func action_id() -> String:
		return "test.mark_event"

	func atomicity() -> String:
		return "atomic"

	func validate(context: RefCounted) -> String:
		return "" if context != null and context.state != null else "event_context_missing"

	func execute(context: RefCounted):
		var entity: RefCounted = context.state.entity(context.source_entity_id)
		if entity == null:
			return ActionResultScript.rejected("event_source_missing")
		entity.tags.grant("event.seen", "ability")
		return ActionResultScript.success()


class IncrementResolver extends RefCounted:
	func build_action() -> RefCounted:
		return AbilityTestIncrementAction.new()


class RejectResolver extends RefCounted:
	func build_action() -> RefCounted:
		return AbilityTestRejectAction.new()


class MarkEventResolver extends RefCounted:
	func build_action() -> RefCounted:
		return AbilityTestMarkEventAction.new()


class BridgeCommitHandler extends RefCounted:
	func handler_id() -> String:
		return "test.bridge_commit"

	func phase() -> String:
		return "commit"

	func priority() -> int:
		return 0

	func scope_rank() -> int:
		return 0

	func owner_sequence() -> int:
		return 0

	func handle(context: RefCounted):
		var fact := DomainEventScript.new(
			"test.committed", {}, "", 0, 1, context.request.source_entity_id, context.request.target_entity_ids
		)
		return EventHandlerResultScript.commit_result([fact])


func run(test: TestSupport) -> void:
	_test_compiles_and_executes_linear_graph(test)
	_test_compile_time_rejections(test)
	_test_ability_run_rolls_back_as_one_transaction(test)
	_test_typed_target_value_flow_and_delay(test)
	_test_bounded_repeat(test)
	_test_graph_variables(test)
	_test_multi_entry_event_trigger(test)
	_test_pipeline_event_bridge(test)
	_test_extension_manifest_registry(test)
	_test_synchronous_subgraph(test)
	_test_owned_async_subgraph(test)
	_test_resource_roundtrip_and_editor_commands(test)
	_test_ability_grant_cost_and_cooldown(test)


func _test_compiles_and_executes_linear_graph(test: TestSupport) -> void:
	var action_registry := _create_action_registry()
	var compiler := GraphCompilerScript.new()
	var graph := _build_linear_graph("test.linear", ["test.increment"])
	var first_compile = compiler.compile(graph, NodeRegistryScript.create_default(), action_registry)
	var second_compile = compiler.compile(graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_true(first_compile.accepted, "valid ability graph must compile: %s" % first_compile.error_code)
	test.assert_true(second_compile.accepted, "same ability graph must compile repeatedly")
	if not first_compile.accepted or not second_compile.accepted:
		return
	test.assert_equal(
		first_compile.plan.operation_order(),
		second_compile.plan.operation_order(),
		"ability compilation order must be deterministic"
	)
	test.assert_equal(
		first_compile.plan.operation_order(),
		["entry", "action_0", "end"],
		"linear graph must compile to its control order"
	)

	var executor := ActionExecutorScript.new()
	var context := FakeCombatContext.new()
	var run_instance := AbilityRunScript.new(
		first_compile.plan, action_registry, executor, "run.linear.1"
	)
	var result = executor.execute(run_instance, context)
	test.assert_true(result.accepted, "compiled ability run must execute: %s" % result.error_code)
	test.assert_equal(context.value, 15, "ability action must change combat context")
	test.assert_equal(result.events.size(), 1, "ability run must forward child action events")
	test.assert_equal(run_instance.state, "ended", "successful ability run must end")
	test.assert_equal(
		run_instance.visited_node_ids,
		["entry", "action_0", "end"],
		"ability run must expose visited nodes for debugging"
	)
	test.assert_true(run_instance.execution_snapshot().trace.size() >= 2, "ability run must retain executed edge trace")
	test.assert_equal(run_instance.execution_snapshot().active_edge.to_node_id, "end", "ability snapshot must expose active edge")
	var debug_registry := AbilityDebugRegistryScript.new()
	test.assert_equal(debug_registry.register_run(run_instance, "entity_a"), "", "debug registry must register active runs")
	test.assert_equal(debug_registry.select_run("run.linear.1"), "", "debug registry must select a run explicitly")
	var debug_snapshot = debug_registry.snapshot("run.linear.1", 4)
	test.assert_equal(debug_snapshot.current_node_id, "end", "debug snapshot must expose current node")
	test.assert_equal(debug_snapshot.owner_entity_id, "entity_a", "debug snapshot must expose run owner")
	test.assert_equal(debug_registry.unregister_run("run.linear.1"), "", "debug registry must release finished runs")
	var repeated = executor.execute(run_instance, context)
	test.assert_equal(repeated.error_code, "ability_run_not_ready", "ability run is single-use")


func _test_compile_time_rejections(test: TestSupport) -> void:
	var action_registry := _create_action_registry()
	var compiler := GraphCompilerScript.new()
	var unknown_type_graph := GraphDefinitionScript.new("test.unknown_type")
	unknown_type_graph.add_node(NodeDefinitionScript.new("mystery", "project.unknown_node"))
	var unknown_type = compiler.compile(
		unknown_type_graph, NodeRegistryScript.create_default(), action_registry
	)
	test.assert_equal(unknown_type.error_code, "unknown_node_type", "unknown node type must fail compile")
	test.assert_equal(unknown_type.node_id, "mystery", "compile errors must preserve source node id")
	var terminal_missing_graph := GraphDefinitionScript.new("test.terminal_missing")
	terminal_missing_graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	var terminal_missing = compiler.compile(terminal_missing_graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_equal(terminal_missing.error_code, "terminal_missing", "ability graph must declare a terminal")

	var bad_pin_graph := _build_linear_graph("test.bad_pin", ["test.increment"])
	bad_pin_graph.connections[0].from_pin_id = "missing_pin"
	var bad_pin = compiler.compile(
		bad_pin_graph, NodeRegistryScript.create_default(), action_registry
	)
	test.assert_equal(bad_pin.error_code, "unknown_output_pin", "unknown pin must fail compile")
	test.assert_equal(bad_pin.pin_id, "missing_pin", "compile errors must preserve source pin id")

	var unknown_action_graph := _build_linear_graph("test.unknown_action", ["project.missing"])
	var unknown_action = compiler.compile(
		unknown_action_graph, NodeRegistryScript.create_default(), action_registry
	)
	test.assert_equal(unknown_action.error_code, "unknown_action", "unknown action must fail compile")
	test.assert_equal(unknown_action.node_id, "action_0", "unknown action must identify its graph node")

	var cycle_graph := _build_cycle_graph()
	var cycle = compiler.compile(cycle_graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_equal(cycle.error_code, "control_cycle", "control cycles must fail compile")
	var typed_graph := GraphDefinitionScript.new("test.pin_type")
	typed_graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	typed_graph.add_node(NodeDefinitionScript.new("select", NodeRegistryScript.SELECT_TARGET_TYPE, ActionNodeConfigurationScript.new("test.increment")))
	typed_graph.add_node(NodeDefinitionScript.new("damage", NodeRegistryScript.DEAL_DAMAGE_TYPE, ActionNodeConfigurationScript.new("test.increment")))
	typed_graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	typed_graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "select", "in"))
	typed_graph.add_connection(ConnectionDefinitionScript.new("select", "then", "damage", "in"))
	typed_graph.add_connection(ConnectionDefinitionScript.new("select", "targets", "damage", "amount", "value"))
	typed_graph.add_connection(ConnectionDefinitionScript.new("damage", "then", "end", "in"))
	var typed_result = compiler.compile(typed_graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_equal(typed_result.error_code, "pin_value_type_mismatch", "typed value pin mismatch must fail compile")


func _test_ability_run_rolls_back_as_one_transaction(test: TestSupport) -> void:
	var action_registry := _create_action_registry()
	var graph := _build_linear_graph("test.rollback", ["test.increment", "test.reject"])
	var compiled = GraphCompilerScript.new().compile(
		graph, NodeRegistryScript.create_default(), action_registry
	)
	test.assert_true(compiled.accepted, "rollback test graph must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	var executor := ActionExecutorScript.new()
	var context := FakeCombatContext.new()
	var run_instance := AbilityRunScript.new(
		compiled.plan, action_registry, executor, "run.rollback.1"
	)
	var result = executor.execute(run_instance, context)
	test.assert_equal(result.error_code, "ability_action_failed", "failed child action must reject ability run")
	test.assert_equal(context.value, 10, "failed ability run must roll back all earlier child actions")
	test.assert_equal(run_instance.state, "failed", "rejected ability run must retain failed debug state")
	test.assert_equal(
		run_instance.last_error_code,
		"forced_failure",
		"ability run debug state must retain child failure code"
	)


func _test_typed_target_value_flow_and_delay(test: TestSupport) -> void:
	var state := CoreStateScript.new()
	var source = state.create_entity("source")
	var target = state.create_entity("target")
	target.attributes.register_definition(AttributeDefinitionScript.new("health", 100.0, 0.0, 100.0))
	var pipeline := preload("res://src/runtime/core/core_event_pipeline.gd").new()
	var damage := DamageModuleScript.new(state, pipeline)
	damage.register()
	var action_registry := _create_action_registry()
	action_registry.register_action("module.target.select", TargetActionResolverScript.new())
	damage.register_actions(action_registry)
	var targets := TargetRegistryScript.new()
	test.assert_equal(targets.register_builtins(), "", "target registry builtins must register explicitly")
	var graph := GraphDefinitionScript.new("test.typed_target")
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(
		NodeDefinitionScript.new(
			"select",
			NodeRegistryScript.SELECT_TARGET_TYPE,
			ActionNodeConfigurationScript.new("module.target.select", {"target_type": "explicit", "entity_ids": ["target"]})
		)
	)
	graph.add_node(
		NodeDefinitionScript.new(
			"damage",
			NodeRegistryScript.DEAL_DAMAGE_TYPE,
			ActionNodeConfigurationScript.new("module.damage.deal", {"amount": 25.0})
		)
	)
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "select", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("select", "then", "damage", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("select", "targets", "damage", "targets", "value"))
	graph.add_connection(ConnectionDefinitionScript.new("damage", "then", "end", "in"))
	var compiled = GraphCompilerScript.new().compile(
		graph, NodeRegistryScript.create_default(), action_registry
	)
	test.assert_true(compiled.accepted, "typed target/value graph must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	var context := ExecutionContextScript.new(state, pipeline, source.entity_id, [], targets)
	var run_instance := AbilityRunScript.new(compiled.plan, action_registry, ActionExecutorScript.new(), "run.typed")
	var result = ActionExecutorScript.new().execute(run_instance, context)
	test.assert_true(result.accepted, "typed target/value graph must execute")
	test.assert_equal(target.attributes.value("health"), 75.0, "target output must feed damage action")
	test.assert_equal(run_instance.state, AbilityRunScript.STATE_ENDED, "typed graph must end")

	var delay_graph := _build_delay_graph()
	var delay_plan = GraphCompilerScript.new().compile(delay_graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_true(delay_plan.accepted, "delay graph must compile")
	if delay_plan.accepted:
		var delay_run := AbilityRunScript.new(delay_plan.plan, action_registry, ActionExecutorScript.new(), "run.delay")
		var delay_context := ExecutionContextScript.new(state, pipeline, source.entity_id, [target.entity_id], targets)
		var delay_result = ActionExecutorScript.new().execute(delay_run, delay_context)
		test.assert_true(delay_result.accepted, "delay run should suspend successfully")
		test.assert_equal(delay_run.state, AbilityRunScript.STATE_WAITING, "delay must enter waiting state")
		var scope_id := delay_run.open_cancel_scope("delay_scope")
		test.assert_equal(scope_id, "delay_scope", "ability run must open a named cancel scope")
		test.assert_equal(delay_run.current_scope_id(), "delay_scope", "new scope must become current")
		test.assert_equal(delay_run.cancel_scope(scope_id), "", "ability run must close a cancel scope")
		test.assert_equal(delay_run.current_scope_id(), "run", "scope close must restore parent scope")
		var saved_delay: Dictionary = delay_run.save_state()
		var restored_delay := AbilityRunScript.new(delay_plan.plan, action_registry, ActionExecutorScript.new(), "run.delay.restored")
		test.assert_equal(restored_delay.restore_state(saved_delay), "", "ability run save state must restore against the same plan")
		test.assert_equal(restored_delay.state, AbilityRunScript.STATE_WAITING, "restored ability run must retain wait state")
		delay_context.logical_tick = 2
		var resumed = delay_run.tick(2)
		test.assert_true(resumed.accepted, "delay run must resume at its deadline")
		test.assert_equal(delay_run.state, AbilityRunScript.STATE_ENDED, "resumed delay run must end")

	var wait_graph := _build_wait_graph()
	var wait_plan = GraphCompilerScript.new().compile(wait_graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_true(wait_plan.accepted, "wait graph must compile")
	if wait_plan.accepted:
		var wait_run := AbilityRunScript.new(wait_plan.plan, action_registry, ActionExecutorScript.new(), "run.wait")
		var wait_context := ExecutionContextScript.new(state, pipeline, source.entity_id, [], targets)
		var wait_result = ActionExecutorScript.new().execute(wait_run, wait_context)
		test.assert_true(wait_result.accepted, "wait run should suspend successfully")
		test.assert_equal(wait_run.state, AbilityRunScript.STATE_WAITING, "wait event must enter waiting state")
		var wrong_event_result = wait_run.resume_event(DomainEventScript.new("damage.applied", {"kind": "normal"}))
		test.assert_equal(wrong_event_result.error_code, "ability_event_filter_not_matched", "wait event filter must reject mismatched payloads")
		var event_result = wait_run.resume_event(DomainEventScript.new("damage.applied", {"kind": "critical"}))
		test.assert_true(event_result.accepted, "matching committed event must resume wait")
		test.assert_equal(wait_run.state, AbilityRunScript.STATE_ENDED, "resumed wait run must end")

	var timeout_graph := _build_wait_timeout_graph()
	var timeout_plan = GraphCompilerScript.new().compile(timeout_graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_true(timeout_plan.accepted, "wait timeout graph must compile")
	if timeout_plan.accepted:
		var timeout_run := AbilityRunScript.new(timeout_plan.plan, action_registry, ActionExecutorScript.new(), "run.wait_timeout")
		var timeout_context := ExecutionContextScript.new(state, pipeline, source.entity_id, [], targets)
		var timeout_result = ActionExecutorScript.new().execute(timeout_run, timeout_context)
		test.assert_true(timeout_result.accepted, "wait timeout run must suspend")
		test.assert_equal(timeout_run.tick(1).accepted, true, "wait timeout must resume on its deadline")
		test.assert_equal(timeout_run.state, AbilityRunScript.STATE_ENDED, "wait timeout must follow timeout route")


func _test_bounded_repeat(test: TestSupport) -> void:
	var action_registry := _create_action_registry()
	var graph := _build_repeat_graph()
	var compiled = GraphCompilerScript.new().compile(graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_true(compiled.accepted, "bounded repeat graph must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	var context := FakeCombatContext.new()
	var run_instance := AbilityRunScript.new(compiled.plan, action_registry, ActionExecutorScript.new(), "run.repeat")
	var result = ActionExecutorScript.new().execute(run_instance, context)
	test.assert_true(result.accepted, "bounded repeat run must execute")
	test.assert_equal(context.value, 20, "bounded repeat must execute exactly its declared count")
	test.assert_equal(run_instance.state, AbilityRunScript.STATE_ENDED, "bounded repeat must reach done route")
	var branch_graph := _build_branch_graph()
	var branch_plan = GraphCompilerScript.new().compile(branch_graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_true(branch_plan.accepted, "branch graph must compile")
	if branch_plan.accepted:
		var branch_context := FakeCombatContext.new()
		var branch_run := AbilityRunScript.new(branch_plan.plan, action_registry, ActionExecutorScript.new(), "run.branch")
		var branch_result = ActionExecutorScript.new().execute(branch_run, branch_context)
		test.assert_true(branch_result.accepted, "branch run must execute selected route")
		test.assert_equal(branch_context.value, 15, "branch condition must select the true route")


func _test_graph_variables(test: TestSupport) -> void:
	var graph := GraphDefinitionScript.new("test.variables")
	graph.add_variable(GraphVariableScript.new("power", "float", 2.5, "save"))
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "end", "in"))
	var registry := _create_action_registry()
	var compiled = GraphCompilerScript.new().compile(graph, NodeRegistryScript.create_default(), registry)
	test.assert_true(compiled.accepted, "graph variables must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	test.assert_equal(compiled.plan.variables().power.default_value, 2.5, "plan must preserve variable defaults")
	var run_instance := AbilityRunScript.new(compiled.plan, registry, ActionExecutorScript.new(), "run.variables")
	var result = ActionExecutorScript.new().execute(run_instance, FakeCombatContext.new())
	test.assert_true(result.accepted, "variable graph must execute")
	test.assert_equal(run_instance.execution_snapshot().values.power, 2.5, "run must initialize variable defaults")
	var mutation_graph := GraphDefinitionScript.new("test.variable_mutation")
	mutation_graph.add_variable(GraphVariableScript.new("power", "float", 2.5, "transient"))
	mutation_graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	mutation_graph.add_node(NodeDefinitionScript.new("write", NodeRegistryScript.WRITE_VARIABLE_TYPE, AbilityNodeConfigurationScript.new({"variable_id": "power", "value": 7.0})))
	mutation_graph.add_node(NodeDefinitionScript.new("read", NodeRegistryScript.READ_VARIABLE_TYPE, AbilityNodeConfigurationScript.new({"variable_id": "power"})))
	mutation_graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	mutation_graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "write", "in"))
	mutation_graph.add_connection(ConnectionDefinitionScript.new("write", "then", "read", "in"))
	mutation_graph.add_connection(ConnectionDefinitionScript.new("read", "then", "end", "in"))
	var mutation = GraphCompilerScript.new().compile(mutation_graph, NodeRegistryScript.create_default(), registry)
	test.assert_true(mutation.accepted, "variable read/write graph must compile: %s" % mutation.error_code)
	if mutation.accepted:
		var mutation_run := AbilityRunScript.new(mutation.plan, registry, ActionExecutorScript.new(), "run.variable_mutation")
		var mutation_result = ActionExecutorScript.new().execute(mutation_run, FakeCombatContext.new())
		test.assert_true(mutation_result.accepted, "variable read/write graph must execute")
		test.assert_equal(mutation_run.execution_snapshot().values.power, 7.0, "variable write must update run-local state")


func _test_multi_entry_event_trigger(test: TestSupport) -> void:
	var graph := GraphDefinitionScript.new("test.multi_entry")
	graph.add_node(NodeDefinitionScript.new("cast", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(NodeDefinitionScript.new("hit", NodeRegistryScript.ON_HIT_TYPE))
	graph.add_node(NodeDefinitionScript.new("hit_action", NodeRegistryScript.EXECUTE_ACTION_TYPE, ActionNodeConfigurationScript.new("test.increment")))
	graph.add_node(NodeDefinitionScript.new("cast_end", NodeRegistryScript.END_TYPE))
	graph.add_node(NodeDefinitionScript.new("hit_end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("cast", "then", "cast_end", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("hit", "then", "hit_action", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("hit_action", "then", "hit_end", "in"))
	var registry := _create_action_registry()
	var compiled = GraphCompilerScript.new().compile(graph, NodeRegistryScript.create_default(), registry)
	test.assert_true(compiled.accepted, "multiple event entries must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	test.assert_equal(compiled.plan.entry_node_ids("hit.resolved"), ["hit"], "hit entry must be indexed by the hit-resolution event type")
	var state := CoreStateScript.new()
	state.create_entity("source")
	var service := AbilityServiceScript.new(state, registry, ActionExecutorScript.new())
	var definition := AbilityDefinitionScript.new("ability.multi", "test.multi_entry")
	test.assert_equal(service.register_definition(definition, compiled.plan), "", "multi-entry ability must register")
	var grant_handle: String = service.grant("source", "ability.multi", "fixture")
	var context := FakeCombatContext.new()
	var event := DomainEventScript.new("hit.resolved", {}, "hit.event", 0, 1, "source", [])
	var results := service.trigger_event(event, context)
	test.assert_equal(results.size(), 1, "event trigger must create one entry run")
	if not results.is_empty():
		test.assert_true(results[0].accepted, "event entry run must execute")
	test.assert_equal(context.value, 15, "event entry must route into its action")
	test.assert_equal(service.active_run_ids(), [], "finished event run must not leak active state")
	test.assert_equal(service.revoke("source", grant_handle), "", "event ability grant must revoke")


func _test_pipeline_event_bridge(test: TestSupport) -> void:
	var graph := GraphDefinitionScript.new("test.pipeline_bridge")
	graph.add_node(NodeDefinitionScript.new("hit", NodeRegistryScript.ON_HIT_TYPE, AbilityNodeConfigurationScript.new({"event_type": "test.committed"})))
	graph.add_node(NodeDefinitionScript.new("mark", NodeRegistryScript.EXECUTE_ACTION_TYPE, ActionNodeConfigurationScript.new("test.mark_event")))
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("hit", "then", "mark", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("mark", "then", "end", "in"))
	var registry := _create_action_registry()
	var compiled = GraphCompilerScript.new().compile(graph, NodeRegistryScript.create_default(), registry)
	test.assert_true(compiled.accepted, "pipeline bridge graph must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	var state := CoreStateScript.new()
	var source = state.create_entity("source")
	var pipeline := EventPipelineScript.new()
	pipeline.register("event.request", BridgeCommitHandler.new())
	var service := AbilityServiceScript.new(state, registry, ActionExecutorScript.new(), null, pipeline)
	var definition := AbilityDefinitionScript.new("ability.bridge", "test.pipeline_bridge")
	test.assert_equal(service.register_definition(definition, compiled.plan), "", "pipeline bridge ability must register")
	service.grant("source", "ability.bridge", "fixture")
	var dispatch_result = pipeline.dispatch(EventRequestScript.new("event.request", {}, "source", []), 3)
	test.assert_true(dispatch_result.accepted, "pipeline observer must preserve event dispatch")
	test.assert_true(source.tags.has_tag("event.seen"), "committed pipeline event must trigger matching ability entry")
	test.assert_equal(service.detach_pipeline(), "", "ability service must detach its event observer")


func _test_extension_manifest_registry(test: TestSupport) -> void:
	var framework := FrameworkRegistryScript.new()
	var descriptor := NodeDescriptorScript.new("project.test.logic.sequence", "sequence", ["in"], ["then"], false, false, "Project", "Project Sequence")
	var manifest := ExtensionManifestScript.new("project.test", 1, [descriptor], {"project.test.mark": MarkEventResolver.new()})
	test.assert_equal(framework.register_manifest(manifest), "", "project extension manifest must register explicitly")
	test.assert_equal(framework.manifest_ids(), ["project.test"], "framework registry must expose deterministic manifest IDs")
	test.assert_true(framework.node_registry.has_descriptor("project.test.logic.sequence"), "extension node must enter shared catalog")
	test.assert_true(framework.action_registry.has_action("project.test.mark"), "extension action must enter shared registry")


func _test_synchronous_subgraph(test: TestSupport) -> void:
	var registry := _create_action_registry()
	var compiler := GraphCompilerScript.new()
	var child = compiler.compile(_build_linear_graph("test.child", ["test.increment"]), NodeRegistryScript.create_default(), registry)
	test.assert_true(child.accepted, "subgraph child must compile")
	if not child.accepted:
		return
	var catalog := SubgraphCatalogScript.new()
	test.assert_equal(catalog.register("test.child", child.plan), "", "subgraph catalog must register a plan")
	var parent := GraphDefinitionScript.new("test.parent")
	parent.add_subgraph_ref(SubgraphReferenceScript.new("test.child"))
	parent.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	parent.add_node(NodeDefinitionScript.new("call", NodeRegistryScript.SUBGRAPH_CALL_TYPE, AbilityNodeConfigurationScript.new({"graph_id": "test.child"})))
	parent.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	parent.add_connection(ConnectionDefinitionScript.new("entry", "then", "call", "in"))
	parent.add_connection(ConnectionDefinitionScript.new("call", "then", "end", "in"))
	var compiled = compiler.compile(parent, NodeRegistryScript.create_default(), registry, catalog)
	test.assert_true(compiled.accepted, "declared subgraph call must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	var context := FakeCombatContext.new()
	var run_instance := AbilityRunScript.new(compiled.plan, registry, ActionExecutorScript.new(), "run.parent", null, catalog)
	var result = ActionExecutorScript.new().execute(run_instance, context)
	test.assert_true(result.accepted, "synchronous subgraph must execute")
	test.assert_equal(context.value, 15, "subgraph child must execute through parent context")
	test.assert_equal(run_instance.state, AbilityRunScript.STATE_ENDED, "synchronous subgraph must return to parent")


func _test_owned_async_subgraph(test: TestSupport) -> void:
	var registry := _create_action_registry()
	var compiler := GraphCompilerScript.new()
	var child = compiler.compile(_build_delay_graph(), NodeRegistryScript.create_default(), registry)
	test.assert_true(child.accepted, "async subgraph child must compile")
	if not child.accepted:
		return
	var catalog := SubgraphCatalogScript.new()
	test.assert_equal(catalog.register("test.delay", child.plan), "", "async subgraph must register")
	var parent := GraphDefinitionScript.new("test.parent_async")
	parent.add_subgraph_ref(SubgraphReferenceScript.new("test.delay"))
	parent.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	parent.add_node(NodeDefinitionScript.new("call", NodeRegistryScript.SUBGRAPH_CALL_TYPE, AbilityNodeConfigurationScript.new({"graph_id": "test.delay"})))
	parent.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	parent.add_connection(ConnectionDefinitionScript.new("entry", "then", "call", "in"))
	parent.add_connection(ConnectionDefinitionScript.new("call", "then", "end", "in"))
	var compiled = compiler.compile(parent, NodeRegistryScript.create_default(), registry, catalog)
	test.assert_true(compiled.accepted, "owned async subgraph must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	var context := ExecutionContextScript.new()
	var run_instance := AbilityRunScript.new(compiled.plan, registry, ActionExecutorScript.new(), "run.parent_async", null, catalog)
	var result = ActionExecutorScript.new().execute(run_instance, context)
	test.assert_true(result.accepted, "owned async subgraph activation must return a wait token")
	test.assert_equal(run_instance.state, AbilityRunScript.STATE_WAITING, "parent must own child wait state")
	var snapshot := run_instance.save_state()
	var restored := AbilityRunScript.new(compiled.plan, registry, ActionExecutorScript.new(), "run.parent_async.restore", null, catalog)
	test.assert_equal(restored.restore_state(snapshot), "", "owned child wait must restore from parent snapshot")
	test.assert_equal(restored.tick(1).error_code, "ability_wait_not_ready", "child delay must retain its deadline")
	var resumed = restored.tick(2)
	test.assert_true(resumed.accepted, "parent must resume after owned child completes")
	test.assert_equal(restored.state, AbilityRunScript.STATE_ENDED, "owned child completion must advance parent")
	var cancellable := AbilityRunScript.new(compiled.plan, registry, ActionExecutorScript.new(), "run.parent_async.cancel", null, catalog)
	ActionExecutorScript.new().execute(cancellable, ExecutionContextScript.new())
	test.assert_equal(cancellable.cancel_scope("run"), "", "parent scope cancellation must be accepted")
	test.assert_equal(cancellable.state, AbilityRunScript.STATE_CANCELLED, "parent scope cancellation must cancel owned child")
	var event_child = compiler.compile(_build_wait_graph(), NodeRegistryScript.create_default(), registry)
	test.assert_true(event_child.accepted, "event-wait subgraph must compile")
	if event_child.accepted:
		var event_catalog := SubgraphCatalogScript.new()
		test.assert_equal(event_catalog.register("test.wait", event_child.plan), "", "event-wait subgraph must register")
		var event_parent := GraphDefinitionScript.new("test.parent_event")
		event_parent.add_subgraph_ref(SubgraphReferenceScript.new("test.wait"))
		event_parent.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
		event_parent.add_node(NodeDefinitionScript.new("call", NodeRegistryScript.SUBGRAPH_CALL_TYPE, AbilityNodeConfigurationScript.new({"graph_id": "test.wait"})))
		event_parent.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
		event_parent.add_connection(ConnectionDefinitionScript.new("entry", "then", "call", "in"))
		event_parent.add_connection(ConnectionDefinitionScript.new("call", "then", "end", "in"))
		var event_compiled = compiler.compile(event_parent, NodeRegistryScript.create_default(), registry, event_catalog)
		test.assert_true(event_compiled.accepted, "event-wait parent must compile")
		if event_compiled.accepted:
			var event_run := AbilityRunScript.new(event_compiled.plan, registry, ActionExecutorScript.new(), "run.parent_event", null, event_catalog)
			ActionExecutorScript.new().execute(event_run, ExecutionContextScript.new())
			test.assert_equal(event_run.resume_event(DomainEventScript.new("damage.applied", {"kind": "normal"})).error_code, "ability_event_filter_not_matched", "owned child must preserve event filters")
			test.assert_true(event_run.resume_event(DomainEventScript.new("damage.applied", {"kind": "critical"})).accepted, "owned child must resume from matching committed event")
			test.assert_equal(event_run.state, AbilityRunScript.STATE_ENDED, "owned event child completion must advance parent")


func _test_resource_roundtrip_and_editor_commands(test: TestSupport) -> void:
	var sample: Resource = ResourceLoader.load(
		"res://authoring/combat/ability_graphs/example_on_cast.tres",
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	)
	test.assert_true(sample is GraphResourceScript, "sample authoring graph must load as AbilityGraphResource")
	if sample is GraphResourceScript:
		test.assert_equal(sample.graph_id, "example.on_cast", "sample graph must preserve stable graph id")
	test.assert_equal(sample.nodes.size(), 3, "sample graph must contain the minimal ability path")
	var plan_catalog := AbilityPlanCatalogScript.new()
	test.assert_equal(plan_catalog.load_default(), "", "generated ability plan catalog must load")
	test.assert_equal(plan_catalog.graph_ids(), ["defense.cast", "example.on_cast"], "plan catalog must expose deterministic graph ids")
	test.assert_true(plan_catalog.has_plan("example.on_cast"), "generated plan catalog must satisfy subgraph lookup contract")
	test.assert_equal(
		plan_catalog.plan("example.on_cast").operation_order(),
		["entry", "action", "end"],
		"generated plan must preserve compiled operation order"
	)
	var graph := GraphResourceScript.new()
	graph.graph_id = "test.resource_roundtrip"
	var entry := NodeResourceScript.new()
	entry.node_id = "entry"
	entry.type_id = NodeRegistryScript.ON_CAST_TYPE
	var action := NodeResourceScript.new()
	action.node_id = "action"
	action.type_id = NodeRegistryScript.EXECUTE_ACTION_TYPE
	action.parameters = {"action_id": "test.increment"}
	var end := NodeResourceScript.new()
	end.node_id = "end"
	end.type_id = NodeRegistryScript.END_TYPE
	graph.add_node_resource(entry, Vector2(40, 80))
	graph.add_node_resource(action, Vector2(280, 80))
	graph.add_node_resource(end, Vector2(520, 80))
	var first_connection := ConnectionResourceScript.new()
	first_connection.from_node_id = "entry"
	first_connection.from_pin_id = "then"
	first_connection.to_node_id = "action"
	first_connection.to_pin_id = "in"
	graph.add_connection_resource(first_connection)
	var second_connection := ConnectionResourceScript.new()
	second_connection.from_node_id = "action"
	second_connection.from_pin_id = "then"
	second_connection.to_node_id = "end"
	second_connection.to_pin_id = "in"
	graph.add_connection_resource(second_connection)
	var path := "user://ability_graph_resource_roundtrip.tres"
	var save_error: Error = ResourceSaver.save(graph, path)
	test.assert_equal(save_error, OK, "AbilityGraphResource must save as text Resource")
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	test.assert_true(loaded is GraphResourceScript, "saved graph must load as AbilityGraphResource")
	if loaded is GraphResourceScript:
		test.assert_equal(
			loaded.document_snapshot(),
			graph.document_snapshot(),
			"AbilityGraphResource save/load must preserve semantic graph and layout"
		)

	var undo_redo := UndoRedo.new()
	var controller := DocumentControllerScript.new(undo_redo)
	controller.set_resource(graph)
	test.assert_equal(
		controller.add_node(NodeRegistryScript.END_TYPE, Vector2(700, 80)),
		"",
		"editor controller must add nodes through a command"
	)
	test.assert_true(graph.nodes.size() == 4, "editor command must update Resource model")
	undo_redo.undo()
	test.assert_true(graph.nodes.size() == 3, "editor command must undo Resource mutation")
	undo_redo.redo()
	test.assert_true(graph.nodes.size() == 4, "editor command must redo Resource mutation")
	test.assert_equal(controller.edit_parameters("action", {"action_id": "test.increment", "amount": 5}), "", "editor parameter command must update typed payload")
	test.assert_equal(graph.node_by_id("action").parameters.amount, 5, "editor parameter command must preserve numeric values")
	test.assert_equal(controller.batch_edit_parameters(["action"], {"amount": 9}), "", "editor batch refactor must use one command")
	test.assert_equal(graph.node_by_id("action").parameters.amount, 9, "editor batch refactor must update selected nodes")
	undo_redo.undo()
	test.assert_equal(graph.node_by_id("action").parameters.amount, 5, "editor batch refactor must undo atomically")
	undo_redo.redo()
	test.assert_equal(controller.edit_comment("action", "Apply the configured hit amount"), "", "editor comment command must update document metadata")
	test.assert_equal(graph.node_comment("action"), "Apply the configured hit amount", "graph resource must preserve node comments")
	var frame_id: String = controller.add_frame("Damage Sequence", Vector2(20, 20))
	test.assert_true(graph.frames.size() == 1, "editor frame command must add a serialized frame")
	test.assert_equal(controller.edit_frame(frame_id, {"title": "Damage Flow"}), "", "editor frame command must edit frame metadata")
	test.assert_equal(graph.frames[0].title, "Damage Flow", "frame title edit must preserve metadata")
	test.assert_equal(controller.remove_frame(frame_id), "", "editor frame command must remove by stable frame id")
	var copy := controller.copy_payload(["action"])
	var pasted := controller.paste_payload(copy, Vector2(40, 40))
	test.assert_equal(pasted.size(), 1, "editor clipboard must paste one remapped node")
	test.assert_true(graph.node_by_id(pasted[0]) != null, "pasted node must receive a stable new id")
	controller.set_resource(null)
	undo_redo.clear_history()
	controller = null
	undo_redo.free()
	undo_redo = null
	loaded = null
	sample = null
	graph = null


func _test_ability_grant_cost_and_cooldown(test: TestSupport) -> void:
	var action_registry := _create_action_registry()
	var compiler := GraphCompilerScript.new()
	var compiled = compiler.compile(
		_build_linear_graph("test.service", ["test.increment"]),
		NodeRegistryScript.create_default(),
		action_registry
	)
	test.assert_true(compiled.accepted, "ability service fixture must compile")
	if not compiled.accepted:
		return
	var state := CoreStateScript.new()
	var entity = state.create_entity("caster")
	entity.attributes.register_definition(AttributeDefinitionScript.new("mana", 10.0, 0.0, 10.0))
	var executor := ActionExecutorScript.new()
	var service := AbilityServiceScript.new(state, action_registry, executor)
	var definition := AbilityDefinitionScript.new("ability.test", "test.service", 2, {"mana": 3.0})
	test.assert_equal(service.register_definition(definition, compiled.plan), "", "ability definition must bind to compiled plan")
	var grant_handle: String = service.grant("caster", "ability.test", "loadout")
	test.assert_not_empty(grant_handle, "ability grant must return a stable handle")
	var context := FakeCombatContext.new()
	var first = service.activate("caster", grant_handle, context)
	test.assert_true(first.accepted, "granted ability must activate")
	test.assert_equal(entity.attributes.value("mana"), 7.0, "ability activation must commit declared cost")
	var blocked = service.activate("caster", grant_handle, context)
	test.assert_equal(blocked.error_code, "ability_on_cooldown", "ability must reject before cooldown expiry")
	state.advance_tick()
	var still_blocked = service.activate("caster", grant_handle, context)
	test.assert_equal(still_blocked.error_code, "ability_on_cooldown", "cooldown uses explicit logical ticks")
	state.advance_tick()
	var second = service.activate("caster", grant_handle, context)
	test.assert_true(second.accepted, "ability must activate after cooldown tick")
	test.assert_equal(entity.attributes.value("mana"), 4.0, "second activation must pay the next cost")
	test.assert_equal(service.revoke("caster", grant_handle), "", "ability grant must revoke by stable handle")
	var wait_compiled = compiler.compile(_build_delay_graph(), NodeRegistryScript.create_default(), action_registry)
	var wait_definition := AbilityDefinitionScript.new("ability.wait", "test.delay")
	test.assert_equal(service.register_definition(wait_definition, wait_compiled.plan), "", "waiting ability must register")
	var wait_handle: String = service.grant("caster", "ability.wait", "loadout")
	var wait_context := ExecutionContextScript.new(state, null, "caster", [])
	var wait_activation = service.activate("caster", wait_handle, wait_context)
	test.assert_true(wait_activation.accepted, "waiting ability must activate")
	var service_snapshot: Dictionary = service.snapshot()
	var waiting_run_ids := service.active_run_ids()
	test.assert_equal(waiting_run_ids.size(), 1, "waiting ability must be included in service snapshot")
	test.assert_equal(service.restore(service_snapshot, {waiting_run_ids[0]: wait_context}), "", "service snapshot must restore active runs")
	test.assert_equal(service.active_run_ids(), waiting_run_ids, "service restore must preserve active run IDs")
	test.assert_equal(service.run(waiting_run_ids[0]).state, AbilityRunScript.STATE_WAITING, "service restore must preserve wait state")
	service.cancel_run(waiting_run_ids[0])
	service.revoke("caster", wait_handle)


func _create_action_registry() -> RefCounted:
	var registry := ActionRegistryScript.new()
	registry.register_action("test.increment", IncrementResolver.new())
	registry.register_action("test.reject", RejectResolver.new())
	registry.register_action("test.mark_event", MarkEventResolver.new())
	return registry


func _build_linear_graph(graph_id: String, action_ids: Array[String]) -> RefCounted:
	var graph := GraphDefinitionScript.new(graph_id)
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	var previous_node_id := "entry"
	for index in range(action_ids.size()):
		var node_id := "action_%d" % index
		graph.add_node(
			NodeDefinitionScript.new(
				node_id,
				NodeRegistryScript.EXECUTE_ACTION_TYPE,
				ActionNodeConfigurationScript.new(action_ids[index])
			)
		)
		graph.add_connection(
			ConnectionDefinitionScript.new(previous_node_id, "then", node_id, "in")
		)
		previous_node_id = node_id
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new(previous_node_id, "then", "end", "in"))
	return graph


func _build_cycle_graph() -> RefCounted:
	var graph := GraphDefinitionScript.new("test.cycle")
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	for node_id in ["cycle_a", "cycle_b"]:
		graph.add_node(
			NodeDefinitionScript.new(
				node_id,
				NodeRegistryScript.EXECUTE_ACTION_TYPE,
				ActionNodeConfigurationScript.new("test.increment")
			)
		)
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "end", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("cycle_a", "then", "cycle_b", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("cycle_b", "then", "cycle_a", "in"))
	return graph


func _build_delay_graph() -> RefCounted:
	var graph := GraphDefinitionScript.new("test.delay")
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(
		NodeDefinitionScript.new(
			"delay",
			NodeRegistryScript.DELAY_TYPE,
			AbilityNodeConfigurationScript.new({"duration_ticks": 2})
		)
	)
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "delay", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("delay", "then", "end", "in"))
	return graph


func _build_wait_graph() -> RefCounted:
	var graph := GraphDefinitionScript.new("test.wait")
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(
		NodeDefinitionScript.new(
			"wait",
			NodeRegistryScript.WAIT_EVENT_TYPE,
			AbilityNodeConfigurationScript.new({"event_type": "damage.applied", "filter": {"kind": "critical"}})
		)
	)
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "wait", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("wait", "resumed", "end", "in"))
	return graph


func _build_wait_timeout_graph() -> RefCounted:
	var graph := GraphDefinitionScript.new("test.wait_timeout")
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(NodeDefinitionScript.new("wait", NodeRegistryScript.WAIT_EVENT_TYPE, AbilityNodeConfigurationScript.new({"event_type": "damage.applied", "timeout_ticks": 1})))
	graph.add_node(NodeDefinitionScript.new("resumed_end", NodeRegistryScript.END_TYPE))
	graph.add_node(NodeDefinitionScript.new("timeout_end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "wait", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("wait", "resumed", "resumed_end", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("wait", "timeout", "timeout_end", "in"))
	return graph


func _build_repeat_graph() -> RefCounted:
	var graph := GraphDefinitionScript.new("test.repeat")
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(
		NodeDefinitionScript.new(
			"repeat",
			NodeRegistryScript.REPEAT_TYPE,
			AbilityNodeConfigurationScript.new({"count": 2})
		)
	)
	graph.add_node(
		NodeDefinitionScript.new(
			"action",
			NodeRegistryScript.EXECUTE_ACTION_TYPE,
			ActionNodeConfigurationScript.new("test.increment")
		)
	)
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "repeat", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("repeat", "body", "action", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("action", "then", "repeat", "continue"))
	graph.add_connection(ConnectionDefinitionScript.new("repeat", "done", "end", "in"))
	return graph


func _build_branch_graph() -> RefCounted:
	var graph := GraphDefinitionScript.new("test.branch")
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(
		NodeDefinitionScript.new(
			"branch",
			NodeRegistryScript.BRANCH_TYPE,
			AbilityNodeConfigurationScript.new({"condition": true})
		)
	)
	graph.add_node(NodeDefinitionScript.new("true_action", NodeRegistryScript.EXECUTE_ACTION_TYPE, ActionNodeConfigurationScript.new("test.increment")))
	graph.add_node(NodeDefinitionScript.new("true_end", NodeRegistryScript.END_TYPE))
	graph.add_node(NodeDefinitionScript.new("false_end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "branch", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("branch", "true", "true_action", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("branch", "false", "false_end", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("true_action", "then", "true_end", "in"))
	return graph
