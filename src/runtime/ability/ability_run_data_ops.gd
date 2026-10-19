class_name AbilityRunDataOps
extends RefCounted


static func resolved_parameters(run: RefCounted, operation: RefCounted) -> Dictionary:
	var result: Dictionary = operation.parameters.duplicate(true)
	for input_pin: String in run._plan.input_value_sources(operation.node_id):
		var source_route: String = run._plan.get_input_source(operation.node_id, input_pin)
		if run._values.has(source_route):
			result[input_pin] = run._values[source_route]
	return result


static func capture_action_outputs(run: RefCounted, operation: RefCounted, context: RefCounted) -> void:
	if not context.has_method("value"):
		return
	for output_pin: String in ["targets", "value", "observation"]:
		var output_route: String = run._plan.route_key(operation.node_id, output_pin)
		var value = context.value(output_pin, null)
		if value != null:
			run._values[output_route] = value


static func evaluate_value(run: RefCounted, operation: RefCounted, context: RefCounted) -> String:
	var variable_id := String(operation.parameters.get("variable_id", ""))
	if not variable_id.is_empty():
		if not run._values.has(variable_id):
			return "unknown_graph_variable"
		run._values[run._plan.route_key(operation.node_id, "value")] = run._values[variable_id]
		return ""
	var attribute_id := String(operation.parameters.get("attribute_id", ""))
	if attribute_id.is_empty() or not context.has_method("read_attribute"):
		return "attribute_read_contract_missing"
	var entity_id := String(operation.parameters.get("entity_id", ""))
	if entity_id.is_empty() and not context.target_entity_ids.is_empty():
		entity_id = context.target_entity_ids[0]
	if entity_id.is_empty():
		entity_id = String(context.source_entity_id)
	var value: float = context.read_attribute(entity_id, attribute_id, 0.0)
	run._values[run._plan.route_key(operation.node_id, "value")] = value
	if context.has_method("set_value"):
		context.set_value("%s.value" % operation.node_id, value)
	return ""


static func write_variable(run: RefCounted, operation: RefCounted) -> String:
	var variable_id := String(operation.parameters.get("variable_id", ""))
	if variable_id.is_empty() or not run._plan.variables().has(variable_id):
		return "unknown_graph_variable"
	var parameters := resolved_parameters(run, operation)
	if not parameters.has("value"):
		return "variable_value_missing"
	run._values[variable_id] = parameters.value
	return ""
