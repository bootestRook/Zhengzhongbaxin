class_name AbilitySubgraphCatalog
extends RefCounted

var _plans: Dictionary = {}
var _dependencies: Dictionary = {}


func register(graph_id: String, plan: RefCounted, dependencies: Array[String] = []) -> String:
	if graph_id.is_empty() or plan == null or not plan.has_method("graph_id"):
		return "invalid_subgraph_plan"
	if plan.graph_id() != graph_id or _plans.has(graph_id):
		return "subgraph_identity_invalid"
	_dependencies[graph_id] = dependencies.duplicate()
	if _has_cycle(graph_id, {}) :
		_dependencies.erase(graph_id)
		return "subgraph_recursion"
	_plans[graph_id] = plan
	return ""


func has_plan(graph_id: String) -> bool:
	return _plans.has(graph_id)


func plan(graph_id: String) -> RefCounted:
	return _plans.get(graph_id)


func graph_ids() -> Array[String]:
	var result: Array[String] = []
	for graph_id: String in _plans:
		result.append(graph_id)
	result.sort()
	return result


func _has_cycle(graph_id: String, visiting: Dictionary) -> bool:
	if visiting.has(graph_id):
		return true
	visiting[graph_id] = true
	for dependency: String in _dependencies.get(graph_id, []):
		if _has_cycle(dependency, visiting):
			return true
	visiting.erase(graph_id)
	return false
