class_name AbilityGraphVariablePolicy
extends RefCounted


static func validate(nodes: Dictionary, variables: Array[RefCounted]) -> String:
	var known: Dictionary = {}
	for variable: RefCounted in variables:
		known[variable.variable_id] = true
	for node_id: String in nodes:
		var node: RefCounted = nodes[node_id]
		if not String(node.type_id).ends_with("read_variable") and not String(node.type_id).ends_with("write_variable"):
			continue
		var parameters: Dictionary = node.configuration.parameters if node.configuration != null else {}
		var variable_id := String(parameters.get("variable_id", ""))
		if variable_id.is_empty():
			return "graph_variable_id_empty"
		if not known.has(variable_id):
			return "unknown_graph_variable"
	return ""
