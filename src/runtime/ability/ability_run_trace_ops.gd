class_name AbilityRunTraceOps
extends RefCounted


static func clear(run: RefCounted) -> void:
	run.trace.clear()
	run.active_edge = {}


static func record_edge(run: RefCounted, operation: RefCounted, output_pin: String, next_node_id: String) -> void:
	run.active_edge = {
		"from_node_id": operation.node_id,
		"output_pin": output_pin,
		"to_node_id": next_node_id,
	}
	run.trace.append({"kind": "edge", "sequence": run.trace.size() + 1, "data": run.active_edge.duplicate(true)})
	while run.trace.size() > 200:
		run.trace.pop_front()
