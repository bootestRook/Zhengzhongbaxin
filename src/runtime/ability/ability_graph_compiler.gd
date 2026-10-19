class_name AbilityGraphCompiler
extends RefCounted

const GraphDefinitionScript = preload(
	"res://src/runtime/ability/ability_graph_definition.gd"
)
const NodeDefinitionScript = preload(
	"res://src/runtime/ability/ability_graph_node_definition.gd"
)
const CompileResultScript = preload(
	"res://src/runtime/ability/ability_graph_compile_result.gd"
)
const ExecutionPlanScript = preload(
	"res://src/runtime/ability/ability_execution_plan.gd"
)
const CyclePolicyScript = preload(
	"res://src/runtime/ability/ability_graph_cycle_policy.gd"
)
const ConnectionPolicyScript = preload(
	"res://src/runtime/ability/ability_graph_connection_policy.gd"
)
const VariablePolicyScript = preload(
	"res://src/runtime/ability/ability_graph_variable_policy.gd"
)
const SubgraphPolicyScript = preload(
	"res://src/runtime/ability/ability_graph_subgraph_policy.gd"
)
func compile(
	graph: RefCounted,
	node_registry: RefCounted,
	action_registry: RefCounted,
	subgraph_catalog: RefCounted = null
) -> AbilityGraphCompileResult:
	var graph_error = _validate_graph_contract(graph, node_registry, action_registry)
	if graph_error != null:
		return graph_error

	var nodes_by_id: Dictionary = {}
	var descriptors_by_id: Dictionary = {}
	var entry_ids: Array[String] = []
	var terminal_count := 0
	for node: RefCounted in graph.nodes:
		var node_error = _register_node(
			node, nodes_by_id, descriptors_by_id, entry_ids, node_registry, action_registry
		)
		if node_error != null:
			return node_error
		terminal_count += 1 if descriptors_by_id[node.node_id].is_terminal else 0
	if entry_ids.is_empty():
		return CompileResultScript.rejected("entry_count_invalid")
	if terminal_count == 0:
		return CompileResultScript.rejected("terminal_missing")
	var variable_result := _validate_variables(graph.variables)
	if not variable_result.is_empty():
		return CompileResultScript.rejected(variable_result)
	var variable_node_result := VariablePolicyScript.validate(nodes_by_id, graph.variables)
	if not variable_node_result.is_empty():
		return CompileResultScript.rejected(variable_node_result)
	var subgraph_result := SubgraphPolicyScript.validate(nodes_by_id, graph.subgraph_refs)
	if not subgraph_result.is_empty():
		return CompileResultScript.rejected(subgraph_result)
	if subgraph_catalog != null and subgraph_catalog.has_method("has_plan"):
		for reference: RefCounted in graph.subgraph_refs:
			if not subgraph_catalog.has_plan(reference.graph_id):
				return CompileResultScript.rejected("unknown_subgraph", reference.graph_id)

	var connections: Array[RefCounted] = graph.connections.duplicate()
	var connection_error = ConnectionPolicyScript.validate(
		connections, nodes_by_id, descriptors_by_id
	)
	if connection_error != null:
		return connection_error

	var order_result: Dictionary = _topological_order(nodes_by_id, connections)
	if not bool(order_result.accepted):
		var cycle_error := CyclePolicyScript.validate_bounded(
			order_result.remaining, nodes_by_id, descriptors_by_id, connections
		)
		if not cycle_error.is_empty():
			return CompileResultScript.rejected(cycle_error)
		var deterministic_order: Array[String] = []
		deterministic_order.assign(order_result.order)
		var remaining: Array[String] = order_result.remaining
		remaining.sort()
		deterministic_order.append_array(remaining)
		order_result.order = deterministic_order
	var reachability_error = _validate_reachability(entry_ids, nodes_by_id, connections)
	if reachability_error != null:
		return reachability_error

	return CompileResultScript.success(
		_build_plan(
			graph.graph_id,
			entry_ids[0],
			order_result.order,
			nodes_by_id,
			descriptors_by_id,
			connections,
			graph.variables,
			entry_ids,
			graph.subgraph_refs
		)
	)
func _validate_graph_contract(
	graph: RefCounted,
	node_registry: RefCounted,
	action_registry: RefCounted
) -> RefCounted:
	if not (graph is GraphDefinitionScript):
		return CompileResultScript.rejected("invalid_graph")
	if graph.graph_id.is_empty():
		return CompileResultScript.rejected("graph_id_empty")
	if node_registry == null or not node_registry.has_method("get_descriptor"):
		return CompileResultScript.rejected("node_registry_missing")
	if action_registry == null or not action_registry.has_method("has_action"):
		return CompileResultScript.rejected("action_registry_missing")
	return null
func _register_node(
	node: RefCounted,
	nodes_by_id: Dictionary,
	descriptors_by_id: Dictionary,
	entry_ids: Array[String],
	node_registry: RefCounted,
	action_registry: RefCounted
) -> RefCounted:
	if not (node is NodeDefinitionScript):
		return CompileResultScript.rejected("invalid_node")
	if node.node_id.is_empty():
		return CompileResultScript.rejected("node_id_empty")
	if nodes_by_id.has(node.node_id):
		return CompileResultScript.rejected("duplicate_node_id", node.node_id)
	var descriptor: RefCounted = node_registry.get_descriptor(node.type_id)
	if descriptor == null:
		return CompileResultScript.rejected("unknown_node_type", node.node_id)
	var validation_error: String = descriptor.validate_node(node, action_registry)
	if not validation_error.is_empty():
		return CompileResultScript.rejected(validation_error, node.node_id)
	nodes_by_id[node.node_id] = node
	descriptors_by_id[node.node_id] = descriptor
	if descriptor.is_entry:
		entry_ids.append(node.node_id)
	return null


func _validate_variables(variables: Array[RefCounted]) -> String:
	var seen: Dictionary = {}
	for variable: RefCounted in variables:
		if variable == null or not variable.has_method("validate"):
			return "invalid_graph_variable"
		var error: String = variable.validate()
		if not error.is_empty():
			return error
		if seen.has(variable.variable_id):
			return "duplicate_graph_variable"
		seen[variable.variable_id] = true
	return ""


func _topological_order(nodes_by_id: Dictionary, connections: Array[RefCounted]) -> Dictionary:
	var indegree: Dictionary = {}
	var adjacency: Dictionary = {}
	for node_id: String in nodes_by_id:
		indegree[node_id] = 0
		adjacency[node_id] = []
	for connection: RefCounted in connections:
		adjacency[connection.from_node_id].append(connection.to_node_id)
		indegree[connection.to_node_id] = int(indegree[connection.to_node_id]) + 1
	var available: Array[String] = []
	for node_id: String in indegree:
		if int(indegree[node_id]) == 0:
			available.append(node_id)
	available.sort()
	var order: Array[String] = []
	while not available.is_empty():
		var node_id: String = available.pop_front()
		order.append(node_id)
		var targets: Array = adjacency[node_id]
		targets.sort()
		for target_id: String in targets:
			indegree[target_id] = int(indegree[target_id]) - 1
			if int(indegree[target_id]) == 0:
				available.append(target_id)
				available.sort()
	var remaining: Array[String] = []
	for node_id: String in indegree:
		if int(indegree[node_id]) > 0:
			remaining.append(node_id)
	return {"accepted": remaining.is_empty(), "order": order, "remaining": remaining}


func _validate_reachability(
	entry_node_ids: Array[String],
	nodes_by_id: Dictionary,
	connections: Array[RefCounted]
) -> RefCounted:
	var adjacency: Dictionary = {}
	for node_id: String in nodes_by_id:
		adjacency[node_id] = []
	for connection: RefCounted in connections:
		adjacency[connection.from_node_id].append(connection.to_node_id)
	var visited: Dictionary = {}
	var pending: Array[String] = entry_node_ids.duplicate()
	while not pending.is_empty():
		var node_id: String = pending.pop_front()
		if visited.has(node_id):
			continue
		visited[node_id] = true
		for target_id: String in adjacency[node_id]:
			pending.append(target_id)
	if visited.size() != nodes_by_id.size():
		var node_ids: Array = nodes_by_id.keys()
		node_ids.sort()
		for node_id: String in node_ids:
			if not visited.has(node_id):
				return CompileResultScript.rejected("unreachable_node", node_id)
	return null
func _build_plan(
	graph_id: String,
	entry_node_id: String,
	operation_order: Array,
	nodes_by_id: Dictionary,
	descriptors_by_id: Dictionary,
	connections: Array[RefCounted],
	graph_variables: Array[RefCounted],
	entry_ids: Array[String],
	subgraph_references: Array[RefCounted]
) -> RefCounted:
	var operations: Dictionary = {}
	for node_id: String in operation_order:
		operations[node_id] = descriptors_by_id[node_id].build_operation(nodes_by_id[node_id])
	var routes: Dictionary = {}
	var value_routes: Dictionary = {}
	for connection: RefCounted in connections:
		if connection.kind == "control":
			routes[ExecutionPlanScript.route_key(connection.from_node_id, connection.from_pin_id)] = (
				connection.to_node_id
			)
		else:
			value_routes[ExecutionPlanScript.route_key(connection.to_node_id, connection.to_pin_id)] = (
				ExecutionPlanScript.route_key(connection.from_node_id, connection.from_pin_id)
			)
	var typed_order: Array[String] = []
	typed_order.assign(operation_order)
	var variables: Dictionary = {}
	for variable: RefCounted in graph_variables:
		variables[variable.variable_id] = variable.to_dictionary()
	var subgraph_refs: Dictionary = {}
	for reference: RefCounted in subgraph_references:
		subgraph_refs[reference.graph_id] = reference.to_dictionary()
	var entry_points: Dictionary = {}
	for entry_id: String in entry_ids:
		var event_type := String(operations[entry_id].parameters.get("event_type", "ability.cast"))
		var event_entries: Array = entry_points.get(event_type, [])
		event_entries.append(entry_id)
		entry_points[event_type] = event_entries
	return ExecutionPlanScript.new(
		graph_id, entry_node_id, operations, routes, typed_order, value_routes, variables, entry_points, subgraph_refs
	)
