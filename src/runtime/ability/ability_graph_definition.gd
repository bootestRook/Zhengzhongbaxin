class_name AbilityGraphDefinition
extends RefCounted

var graph_id: String = ""
var nodes: Array[RefCounted] = []
var connections: Array[RefCounted] = []
var variables: Array[RefCounted] = []
var subgraph_refs: Array[RefCounted] = []


func _init(definition_graph_id: String = "") -> void:
	graph_id = definition_graph_id


func add_node(node: RefCounted) -> void:
	nodes.append(node)


func add_connection(connection: RefCounted) -> void:
	connections.append(connection)


func add_variable(variable: RefCounted) -> void:
	variables.append(variable)


func add_subgraph_ref(reference: RefCounted) -> void:
	subgraph_refs.append(reference)
