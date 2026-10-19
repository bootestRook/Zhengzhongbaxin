class_name AbilityGraphConnectionPolicy
extends RefCounted

const ConnectionDefinitionScript = preload(
	"res://src/runtime/ability/ability_graph_connection_definition.gd"
)
const ExecutionPlanScript = preload("res://src/runtime/ability/ability_execution_plan.gd")
const CompileResultScript = preload(
	"res://src/runtime/ability/ability_graph_compile_result.gd"
)


static func validate(
	graph_connections: Array[RefCounted],
	nodes_by_id: Dictionary,
	descriptors_by_id: Dictionary
) -> RefCounted:
	var validated: Array[RefCounted] = []
	for connection: RefCounted in graph_connections:
		if not (connection is ConnectionDefinitionScript):
			return CompileResultScript.rejected("invalid_connection")
		if not ["control", "value", "owned_scope"].has(connection.kind):
			return CompileResultScript.rejected("unsupported_connection_kind", connection.from_node_id)
		if not nodes_by_id.has(connection.from_node_id):
			return CompileResultScript.rejected("unknown_source_node", connection.from_node_id)
		if not nodes_by_id.has(connection.to_node_id):
			return CompileResultScript.rejected("unknown_target_node", connection.to_node_id)
		var source_descriptor: RefCounted = descriptors_by_id[connection.from_node_id]
		var target_descriptor: RefCounted = descriptors_by_id[connection.to_node_id]
		if not source_descriptor.has_output_pin(connection.from_pin_id):
			return CompileResultScript.rejected("unknown_output_pin", connection.from_node_id, connection.from_pin_id)
		if not target_descriptor.has_input_pin(connection.to_pin_id):
			return CompileResultScript.rejected("unknown_input_pin", connection.to_node_id, connection.to_pin_id)
		var source_pin: RefCounted = source_descriptor.output_pin(connection.from_pin_id)
		var target_pin: RefCounted = target_descriptor.input_pin(connection.to_pin_id)
		if source_pin == null or target_pin == null:
			return CompileResultScript.rejected("pin_descriptor_missing", connection.from_node_id)
		if source_pin.kind != connection.kind or target_pin.kind != connection.kind:
			return CompileResultScript.rejected("connection_kind_mismatch", connection.from_node_id, connection.from_pin_id)
		var compatibility_error: String = target_pin.accepts(source_pin)
		if not compatibility_error.is_empty():
			return CompileResultScript.rejected(compatibility_error, connection.to_node_id, connection.to_pin_id)
		validated.append(connection)
	return _validate_cardinality(validated, nodes_by_id, descriptors_by_id)


static func _validate_cardinality(
	connections: Array[RefCounted],
	nodes_by_id: Dictionary,
	descriptors_by_id: Dictionary
) -> RefCounted:
	var output_counts: Dictionary = {}
	var input_counts: Dictionary = {}
	for connection: RefCounted in connections:
		var output_key := ExecutionPlanScript.route_key(connection.from_node_id, connection.from_pin_id)
		var input_key := ExecutionPlanScript.route_key(connection.to_node_id, connection.to_pin_id)
		output_counts[output_key] = int(output_counts.get(output_key, 0)) + 1
		input_counts[input_key] = int(input_counts.get(input_key, 0)) + 1
	for node_id: String in nodes_by_id:
		var descriptor: RefCounted = descriptors_by_id[node_id]
		for input_pin: String in descriptor.input_pins:
			var pin: RefCounted = descriptor.input_pin(input_pin)
			var count := int(input_counts.get(ExecutionPlanScript.route_key(node_id, input_pin), 0))
			if pin.required and count != 1:
				return CompileResultScript.rejected("missing_input_connection", node_id, input_pin)
			if pin.cardinality == "one" and count > 1:
				return CompileResultScript.rejected("duplicate_input_connection", node_id, input_pin)
		for output_pin: String in descriptor.output_pins:
			var pin: RefCounted = descriptor.output_pin(output_pin)
			var count := int(output_counts.get(ExecutionPlanScript.route_key(node_id, output_pin), 0))
			if pin.required and count != 1:
				return CompileResultScript.rejected("missing_output_connection", node_id, output_pin)
			if pin.cardinality == "one" and count > 1:
				return CompileResultScript.rejected("duplicate_output_connection", node_id, output_pin)
	return null
