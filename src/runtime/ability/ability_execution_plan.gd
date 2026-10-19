class_name AbilityExecutionPlan
extends RefCounted

const OperationScript = preload("res://src/runtime/ability/ability_plan_operation.gd")

var _graph_id: String = ""
var _entry_node_id: String = ""
var _entry_points: Dictionary = {}
var _operations: Dictionary = {}
var _routes: Dictionary = {}
var _value_routes: Dictionary = {}
var _variables: Dictionary = {}
var _subgraph_refs: Dictionary = {}
var _operation_order: Array[String] = []


func _init(
	plan_graph_id: String = "",
	plan_entry_node_id: String = "",
	plan_operations: Dictionary = {},
	plan_routes: Dictionary = {},
	plan_operation_order: Array[String] = [],
	plan_value_routes: Dictionary = {},
	plan_variables: Dictionary = {},
	plan_entry_points: Dictionary = {},
	plan_subgraph_refs: Dictionary = {}
) -> void:
	_graph_id = plan_graph_id
	_entry_node_id = plan_entry_node_id
	_entry_points = plan_entry_points.duplicate(true)
	_operations = plan_operations.duplicate()
	_routes = plan_routes.duplicate()
	_value_routes = plan_value_routes.duplicate(true)
	_variables = plan_variables.duplicate(true)
	_subgraph_refs = plan_subgraph_refs.duplicate(true)
	_operation_order = plan_operation_order.duplicate()


func graph_id() -> String:
	return _graph_id


func entry_node_id() -> String:
	return _entry_node_id


func entry_node_ids(event_type: String = "ability.cast") -> Array[String]:
	var result: Array[String] = []
	for node_id: String in _entry_points.get(event_type, []):
		result.append(node_id)
	return result


func entry_event_types() -> Array[String]:
	var result: Array[String] = _entry_points.keys()
	result.sort()
	return result


func operation_count() -> int:
	return _operation_order.size()


func operation_order() -> Array[String]:
	return _operation_order.duplicate()


func get_operation(node_id: String) -> RefCounted:
	return _operations.get(node_id)


func get_next_node(node_id: String, output_pin_id: String) -> String:
	return String(_routes.get(route_key(node_id, output_pin_id), ""))


func get_input_source(node_id: String, input_pin_id: String) -> String:
	return String(_value_routes.get(route_key(node_id, input_pin_id), ""))


func input_value_sources(node_id: String) -> Dictionary:
	var prefix := "%s::" % node_id
	var result: Dictionary = {}
	for route_key_value: String in _value_routes:
		if route_key_value.begins_with(prefix):
			result[route_key_value.trim_prefix(prefix)] = _value_routes[route_key_value]
	return result


func variables() -> Dictionary:
	return _variables.duplicate(true)


func subgraph_refs() -> Dictionary:
	return _subgraph_refs.duplicate(true)


func default_values() -> Dictionary:
	var result: Dictionary = {}
	for variable_id: String in _variables:
		result[variable_id] = _variables[variable_id].get("default_value", null)
	return result


func to_dictionary() -> Dictionary:
	var serialized_operations: Array[Dictionary] = []
	for node_id: String in _operation_order:
		var operation: RefCounted = _operations[node_id]
		serialized_operations.append(
			{
				"node_id": operation.node_id,
				"kind": operation.kind,
				"action_id": operation.action_id,
				"default_output_pin": operation.default_output_pin,
				"parameters": operation.parameters.duplicate(true),
			}
		)
	return {
		"graph_id": _graph_id,
		"entry_node_id": _entry_node_id,
		"entry_points": _entry_points.duplicate(true),
		"operation_order": _operation_order.duplicate(),
		"operations": serialized_operations,
		"routes": _routes.duplicate(true),
		"value_routes": _value_routes.duplicate(true),
		"variables": _variables.duplicate(true),
		"subgraph_refs": _subgraph_refs.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> AbilityExecutionPlan:
	var operations: Dictionary = {}
	for operation_data: Dictionary in data.get("operations", []):
		var operation := OperationScript.new(
			String(operation_data.get("node_id", "")),
			String(operation_data.get("kind", "")),
			String(operation_data.get("action_id", "")),
			String(operation_data.get("default_output_pin", "")),
			operation_data.get("parameters", {}).duplicate(true)
		)
		operations[operation.node_id] = operation
	var order: Array[String] = []
	for node_id: String in data.get("operation_order", []):
		order.append(node_id)
	var routes: Dictionary = data.get("routes", {}).duplicate(true)
	var value_routes: Dictionary = data.get("value_routes", {}).duplicate(true)
	var variables: Dictionary = data.get("variables", {}).duplicate(true)
	var entry_points: Dictionary = data.get("entry_points", {}).duplicate(true)
	var subgraph_refs: Dictionary = data.get("subgraph_refs", {}).duplicate(true)
	return AbilityExecutionPlan.new(
		String(data.get("graph_id", "")),
		String(data.get("entry_node_id", "")),
		operations,
		routes,
		order,
		value_routes,
		variables,
		entry_points,
		subgraph_refs
	)


static func route_key(node_id: String, output_pin_id: String) -> String:
	return "%s::%s" % [node_id, output_pin_id]
