@tool
class_name AbilityGraphResource
extends Resource

const CURRENT_SCHEMA_VERSION := 2
const NodeResourceScript = preload(
	"res://src/runtime/ability/ability_graph_node_resource.gd"
)
const ConnectionResourceScript = preload(
	"res://src/runtime/ability/ability_graph_connection_resource.gd"
)
const DefinitionScript = preload(
	"res://src/runtime/ability/ability_graph_definition.gd"
)
const VariableScript = preload("res://src/runtime/ability/ability_graph_variable_definition.gd")
const SubgraphReferenceScript = preload("res://src/runtime/ability/ability_subgraph_reference.gd")

@export var graph_id: String = ""
@export var schema_version: int = CURRENT_SCHEMA_VERSION
@export var nodes: Array[AbilityGraphNodeResource] = []
@export var connections: Array[AbilityGraphConnectionResource] = []
@export var variables: Array[Dictionary] = []
@export var subgraph_refs: Array[Dictionary] = []
@export var node_layout: Dictionary = {}
@export var node_sizes: Dictionary = {}
@export var node_comments: Dictionary = {}
@export var frames: Array[Dictionary] = []
@export var editor_scroll_offset: Vector2 = Vector2.ZERO
@export var editor_zoom: float = 1.0


func to_definition() -> RefCounted:
	var definition = DefinitionScript.new(graph_id)
	for node: AbilityGraphNodeResource in nodes:
		definition.add_node(node.to_definition())
	for connection: AbilityGraphConnectionResource in connections:
		definition.add_connection(connection.to_definition())
	for variable_data: Dictionary in variables:
		definition.add_variable(VariableScript.new(
			String(variable_data.get("variable_id", "")),
			String(variable_data.get("value_type", "")),
			variable_data.get("default_value", null),
			String(variable_data.get("save_behavior", "transient"))
		))
	for reference_data: Dictionary in subgraph_refs:
		definition.add_subgraph_ref(SubgraphReferenceScript.new(
			String(reference_data.get("graph_id", "")),
			reference_data.get("input_types", {}),
			reference_data.get("output_types", {})
		))
	return definition


func schema_error() -> String:
	if schema_version != CURRENT_SCHEMA_VERSION:
		return "unsupported_graph_schema_version"
	if graph_id.is_empty():
		return "graph_id_empty"
	return ""


func node_by_id(node_id_to_find: String) -> AbilityGraphNodeResource:
	for node: AbilityGraphNodeResource in nodes:
		if node.node_id == node_id_to_find:
			return node
	return null


func node_position(node_id_to_find: String) -> Vector2:
	var raw_position: Variant = node_layout.get(node_id_to_find, Vector2.ZERO)
	return raw_position if raw_position is Vector2 else Vector2.ZERO


func node_size(node_id_to_find: String) -> Vector2:
	var raw_size: Variant = node_sizes.get(node_id_to_find, Vector2.ZERO)
	return raw_size if raw_size is Vector2 else Vector2.ZERO


func node_comment(node_id_to_find: String) -> String:
	return String(node_comments.get(node_id_to_find, ""))


func set_node_position(node_id_to_set: String, position: Vector2) -> void:
	node_layout[node_id_to_set] = position
	emit_changed()


func set_node_size(node_id_to_set: String, size: Vector2) -> void:
	node_sizes[node_id_to_set] = size
	emit_changed()


func set_node_comment(node_id_to_set: String, comment: String) -> void:
	node_comments[node_id_to_set] = comment
	emit_changed()


func add_node_resource(node: AbilityGraphNodeResource, position: Vector2 = Vector2.ZERO) -> String:
	if node == null or node.node_id.is_empty():
		return "node_id_empty"
	if node_by_id(node.node_id) != null:
		return "duplicate_node_id"
	nodes.append(node)
	node_layout[node.node_id] = position
	emit_changed()
	return ""


func remove_node_resource(node_id_to_remove: String) -> String:
	var index := -1
	for candidate_index in range(nodes.size()):
		if nodes[candidate_index].node_id == node_id_to_remove:
			index = candidate_index
			break
	if index < 0:
		return "unknown_node"
	nodes.remove_at(index)
	node_layout.erase(node_id_to_remove)
	node_sizes.erase(node_id_to_remove)
	node_comments.erase(node_id_to_remove)
	var remaining_connections: Array[AbilityGraphConnectionResource] = []
	for connection: AbilityGraphConnectionResource in connections:
		if connection.from_node_id != node_id_to_remove and connection.to_node_id != node_id_to_remove:
			remaining_connections.append(connection)
	connections = remaining_connections
	emit_changed()
	return ""


func add_connection_resource(connection: AbilityGraphConnectionResource) -> String:
	if connection == null:
		return "invalid_connection"
	for existing: AbilityGraphConnectionResource in connections:
		if (
			existing.from_node_id == connection.from_node_id
			and existing.from_pin_id == connection.from_pin_id
			and existing.to_node_id == connection.to_node_id
			and existing.to_pin_id == connection.to_pin_id
		):
			return "duplicate_connection"
	connections.append(connection)
	emit_changed()
	return ""


func remove_connection_resource(
	from_node_id_to_remove: String,
	from_pin_id_to_remove: String,
	to_node_id_to_remove: String,
	to_pin_id_to_remove: String
) -> String:
	for index in range(connections.size()):
		var connection: AbilityGraphConnectionResource = connections[index]
		if (
			connection.from_node_id == from_node_id_to_remove
			and connection.from_pin_id == from_pin_id_to_remove
			and connection.to_node_id == to_node_id_to_remove
			and connection.to_pin_id == to_pin_id_to_remove
		):
			connections.remove_at(index)
			emit_changed()
			return ""
	return "unknown_connection"


func document_snapshot() -> Dictionary:
	var snapshot_nodes: Array[Dictionary] = []
	for node: AbilityGraphNodeResource in nodes:
		snapshot_nodes.append(
			{
				"node_id": node.node_id,
				"type_id": node.type_id,
				"parameters": node.parameters.duplicate(true),
				"position": node_position(node.node_id),
				"size": node_size(node.node_id),
				"comment": node_comment(node.node_id),
			}
		)
	var snapshot_connections: Array[Dictionary] = []
	for connection: AbilityGraphConnectionResource in connections:
		snapshot_connections.append(
			{
				"from_node_id": connection.from_node_id,
				"from_pin_id": connection.from_pin_id,
				"to_node_id": connection.to_node_id,
				"to_pin_id": connection.to_pin_id,
				"kind": connection.kind,
			}
		)
	return {
		"graph_id": graph_id,
		"schema_version": schema_version,
		"nodes": snapshot_nodes,
		"connections": snapshot_connections,
		"variables": variables.duplicate(true),
		"subgraph_refs": subgraph_refs.duplicate(true),
		"editor_scroll_offset": editor_scroll_offset,
		"editor_zoom": editor_zoom,
		"node_sizes": node_sizes.duplicate(true),
		"node_comments": node_comments.duplicate(true),
		"frames": frames.duplicate(true),
	}


func apply_document_snapshot(snapshot: Dictionary) -> void:
	graph_id = String(snapshot.get("graph_id", ""))
	schema_version = int(snapshot.get("schema_version", CURRENT_SCHEMA_VERSION))
	nodes.clear()
	node_layout.clear()
	node_sizes.clear()
	node_comments.clear()
	for node_data: Dictionary in snapshot.get("nodes", []):
		var node := NodeResourceScript.new()
		node.node_id = String(node_data.get("node_id", ""))
		node.type_id = String(node_data.get("type_id", ""))
		node.parameters = node_data.get("parameters", {}).duplicate(true)
		nodes.append(node)
		node_layout[node.node_id] = node_data.get("position", Vector2.ZERO)
		node_sizes[node.node_id] = node_data.get("size", Vector2.ZERO)
		node_comments[node.node_id] = String(node_data.get("comment", ""))
	connections.clear()
	for connection_data: Dictionary in snapshot.get("connections", []):
		var connection := ConnectionResourceScript.new()
		connection.from_node_id = String(connection_data.get("from_node_id", ""))
		connection.from_pin_id = String(connection_data.get("from_pin_id", ""))
		connection.to_node_id = String(connection_data.get("to_node_id", ""))
		connection.to_pin_id = String(connection_data.get("to_pin_id", ""))
		connection.kind = String(connection_data.get("kind", "control"))
		connections.append(connection)
	variables = snapshot.get("variables", []).duplicate(true)
	subgraph_refs = snapshot.get("subgraph_refs", []).duplicate(true)
	node_sizes = snapshot.get("node_sizes", {}).duplicate(true)
	node_comments = snapshot.get("node_comments", {}).duplicate(true)
	frames = snapshot.get("frames", []).duplicate(true)
	editor_scroll_offset = snapshot.get("editor_scroll_offset", Vector2.ZERO)
	editor_zoom = float(snapshot.get("editor_zoom", 1.0))
	emit_changed()
