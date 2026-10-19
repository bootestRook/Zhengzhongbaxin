class_name AbilityGraphCyclePolicy
extends RefCounted


static func validate_bounded(
	remaining: Array[String],
	nodes_by_id: Dictionary,
	descriptors_by_id: Dictionary,
	connections: Array[RefCounted]
) -> String:
	var repeat_ids: Dictionary = {}
	for node_id: String in remaining:
		var descriptor: RefCounted = descriptors_by_id[node_id]
		if descriptor.operation_kind == "repeat":
			var configuration: RefCounted = nodes_by_id[node_id].configuration
			var count := int(configuration.parameters.get("count", 0)) if configuration != null else 0
			if count <= 0 or count > 64:
				return "repeat_bound_invalid"
			repeat_ids[node_id] = true
	if repeat_ids.is_empty():
		return "control_cycle"
	var adjacency: Dictionary = {}
	for node_id: String in remaining:
		adjacency[node_id] = []
	for connection: RefCounted in connections:
		if connection.kind != "control" or not adjacency.has(connection.from_node_id) or not adjacency.has(connection.to_node_id):
			continue
		adjacency[connection.from_node_id].append(connection.to_node_id)
	var visited: Dictionary = {}
	for root_id: String in remaining:
		if visited.has(root_id):
			continue
		var queue: Array[String] = [root_id]
		var component_has_repeat := false
		while not queue.is_empty():
			var node_id: String = queue.pop_front()
			if visited.has(node_id):
				continue
			visited[node_id] = true
			component_has_repeat = component_has_repeat or repeat_ids.has(node_id)
			for next_id: String in adjacency[node_id]:
				queue.append(next_id)
			for candidate_id: String in remaining:
				if adjacency[candidate_id].has(node_id):
					queue.append(candidate_id)
		if not component_has_repeat:
			return "control_cycle"
	return ""
