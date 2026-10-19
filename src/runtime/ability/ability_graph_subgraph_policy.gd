class_name AbilityGraphSubgraphPolicy
extends RefCounted


static func validate(nodes: Dictionary, references: Array[RefCounted]) -> String:
	var known: Dictionary = {}
	for reference: RefCounted in references:
		if reference == null or not reference.has_method("validate"):
			return "invalid_subgraph_reference"
		var reference_error: String = reference.validate()
		if not reference_error.is_empty():
			return reference_error
		if known.has(reference.graph_id):
			return "duplicate_subgraph_reference"
		known[reference.graph_id] = true
	for node_id: String in nodes:
		var node: RefCounted = nodes[node_id]
		if node.type_id != "combat.ability.logic.subgraph_call":
			continue
		var parameters: Dictionary = node.configuration.parameters if node.configuration != null else {}
		var graph_id := String(parameters.get("graph_id", ""))
		if graph_id.is_empty():
			return "subgraph_id_empty"
		if String(parameters.get("mode", "owned")) != "owned":
			return "subgraph_lifetime_not_owned"
		if not known.has(graph_id):
			return "undeclared_subgraph_reference"
	return ""
