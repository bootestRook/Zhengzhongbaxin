@tool
class_name AbilityGraphDocumentController
extends RefCounted

const GraphResourceScript = preload("res://src/runtime/ability/ability_graph_resource.gd")
const NodeResourceScript = preload("res://src/runtime/ability/ability_graph_node_resource.gd")
const ConnectionResourceScript = preload(
	"res://src/runtime/ability/ability_graph_connection_resource.gd"
)
const NodeRegistryScript = preload("res://src/runtime/ability/ability_node_registry.gd")
const CompilerScript = preload("res://src/runtime/ability/ability_graph_compiler.gd")
const CompileResultScript = preload(
	"res://src/runtime/ability/ability_graph_compile_result.gd"
)

signal document_changed

var _resource: RefCounted
var _undo_redo: Object
var _node_registry: RefCounted = NodeRegistryScript.create_default()


func _init(undo_redo: Object = null) -> void:
	_undo_redo = undo_redo


func set_resource(graph_resource: RefCounted) -> String:
	if graph_resource != null and not (graph_resource is GraphResourceScript):
		return "invalid_graph_resource"
	_resource = graph_resource
	document_changed.emit()
	return ""


func resource() -> RefCounted:
	return _resource


func node_registry() -> RefCounted:
	return _node_registry


func set_node_registry(registry: RefCounted) -> String:
	if registry == null or not registry.has_method("get_descriptor") or not registry.has_method("descriptors"):
		return "invalid_node_registry"
	_node_registry = registry
	document_changed.emit()
	return ""


func descriptor(type_id: String) -> RefCounted:
	return _node_registry.get_descriptor(type_id)


func apply_snapshot(snapshot: Dictionary) -> void:
	if _resource == null:
		return
	_resource.apply_document_snapshot(snapshot)
	document_changed.emit()


func add_node(type_id: String, position: Vector2) -> String:
	if _resource == null:
		return "graph_resource_missing"
	if descriptor(type_id) == null:
		return "unknown_node_type"
	var before: Dictionary = _resource.document_snapshot()
	var node_id := _next_node_id(type_id, before)
	var after: Dictionary = before.duplicate(true)
	var parameters: Dictionary = {}
	var node_descriptor: RefCounted = descriptor(type_id)
	if node_descriptor != null and node_descriptor.operation_kind == "action":
		parameters["action_id"] = "editor.placeholder"
	after.nodes.append(
		{
			"node_id": node_id,
			"type_id": type_id,
			"parameters": parameters,
			"position": position,
		}
	)
	_commit("Add %s" % descriptor(type_id).display_name, before, after)
	return ""


func delete_nodes(node_ids: Array[String]) -> String:
	if _resource == null:
		return "graph_resource_missing"
	var before: Dictionary = _resource.document_snapshot()
	var wanted: Dictionary = {}
	for node_id: String in node_ids:
		wanted[node_id] = true
	var after: Dictionary = before.duplicate(true)
	var kept_nodes: Array[Dictionary] = []
	for node_data: Dictionary in before.nodes:
		if not wanted.has(String(node_data.node_id)):
			kept_nodes.append(node_data)
	after.nodes = kept_nodes
	var kept_connections: Array[Dictionary] = []
	for connection: Dictionary in before.connections:
		if not wanted.has(String(connection.from_node_id)) and not wanted.has(String(connection.to_node_id)):
			kept_connections.append(connection)
	after.connections = kept_connections
	_commit("Delete Ability Nodes", before, after)
	return ""


func connect_nodes(
	from_node_id: String,
	from_pin_id: String,
	to_node_id: String,
	to_pin_id: String
) -> String:
	if _resource == null:
		return "graph_resource_missing"
	var from_node = _resource.node_by_id(from_node_id)
	var to_node = _resource.node_by_id(to_node_id)
	if from_node == null:
		return "unknown_source_node"
	if to_node == null:
		return "unknown_target_node"
	var from_descriptor: RefCounted = descriptor(from_node.type_id)
	var to_descriptor: RefCounted = descriptor(to_node.type_id)
	if from_descriptor == null or not from_descriptor.has_output_pin(from_pin_id):
		return "unknown_output_pin"
	if to_descriptor == null or not to_descriptor.has_input_pin(to_pin_id):
		return "unknown_input_pin"
	var from_pin: RefCounted = from_descriptor.output_pin(from_pin_id)
	var to_pin: RefCounted = to_descriptor.input_pin(to_pin_id)
	if from_pin == null or to_pin == null:
		return "pin_descriptor_missing"
	if from_pin.kind != to_pin.kind:
		return "connection_kind_mismatch"
	var compatibility_error: String = to_pin.accepts(from_pin)
	if not compatibility_error.is_empty():
		return compatibility_error
	var before: Dictionary = _resource.document_snapshot()
	var after: Dictionary = before.duplicate(true)
	var kept_connections: Array[Dictionary] = []
	for connection: Dictionary in before.connections:
		var same_output: bool = connection.from_node_id == from_node_id and connection.from_pin_id == from_pin_id
		var same_input: bool = connection.to_node_id == to_node_id and connection.to_pin_id == to_pin_id
		if not same_output and not same_input:
			kept_connections.append(connection)
	after.connections = kept_connections
	after.connections.append(
		{
			"from_node_id": from_node_id,
			"from_pin_id": from_pin_id,
			"to_node_id": to_node_id,
			"to_pin_id": to_pin_id,
			"kind": from_pin.kind,
		}
	)
	_commit("Connect Ability Nodes", before, after)
	return ""


func disconnect_nodes(
	from_node_id: String,
	from_pin_id: String,
	to_node_id: String,
	to_pin_id: String
) -> String:
	if _resource == null:
		return "graph_resource_missing"
	var before: Dictionary = _resource.document_snapshot()
	var after: Dictionary = before.duplicate(true)
	var found := false
	var kept_connections: Array[Dictionary] = []
	for connection: Dictionary in before.connections:
		var matches: bool = (
			connection.from_node_id == from_node_id
			and connection.from_pin_id == from_pin_id
			and connection.to_node_id == to_node_id
			and connection.to_pin_id == to_pin_id
		)
		if matches:
			found = true
		else:
			kept_connections.append(connection)
	if not found:
		return "unknown_connection"
	after.connections = kept_connections
	_commit("Disconnect Ability Nodes", before, after)
	return ""


func edit_action_id(node_id: String, action_id: String) -> String:
	if _resource == null:
		return "graph_resource_missing"
	var before: Dictionary = _resource.document_snapshot()
	var after: Dictionary = before.duplicate(true)
	for node_data: Dictionary in after.nodes:
		if node_data.node_id == node_id:
			var parameters: Dictionary = node_data.parameters.duplicate(true)
			parameters["action_id"] = action_id
			node_data.parameters = parameters
			_commit("Edit Action Parameter", before, after)
			return ""
	return "unknown_node"


func edit_parameters(node_id: String, parameters: Dictionary) -> String:
	if _resource == null:
		return "graph_resource_missing"
	var before: Dictionary = _resource.document_snapshot()
	var after: Dictionary = before.duplicate(true)
	for node_data: Dictionary in after.nodes:
		if node_data.node_id == node_id:
			node_data.parameters = parameters.duplicate(true)
			_commit("Edit Node Parameters", before, after)
			return ""
	return "unknown_node"


func batch_edit_parameters(node_ids: Array[String], changes: Dictionary) -> String:
	if _resource == null:
		return "graph_resource_missing"
	if node_ids.is_empty() or changes.is_empty():
		return "batch_edit_empty"
	var before: Dictionary = _resource.document_snapshot()
	var wanted: Dictionary = {}
	for node_id: String in node_ids:
		wanted[node_id] = true
	var changed := false
	var after: Dictionary = before.duplicate(true)
	for node_data: Dictionary in after.nodes:
		if not wanted.has(String(node_data.get("node_id", ""))):
			continue
		var parameters: Dictionary = node_data.parameters.duplicate(true)
		for field_id: String in changes:
			parameters[field_id] = changes[field_id]
		node_data.parameters = parameters
		changed = true
	if not changed:
		return "unknown_node"
	_commit("Batch Edit Ability Parameters", before, after)
	return ""


func edit_comment(node_id: String, comment: String) -> String:
	if _resource == null:
		return "graph_resource_missing"
	if _resource.node_by_id(node_id) == null:
		return "unknown_node"
	var before: Dictionary = _resource.document_snapshot()
	var after: Dictionary = before.duplicate(true)
	var comments: Dictionary = after.get("node_comments", {}).duplicate(true)
	comments[node_id] = comment
	after.node_comments = comments
	_commit("Edit Node Comment", before, after)
	return ""


func resize_nodes(sizes: Dictionary) -> String:
	if _resource == null:
		return "graph_resource_missing"
	var before: Dictionary = _resource.document_snapshot()
	var after: Dictionary = before.duplicate(true)
	after.node_sizes = sizes.duplicate(true)
	_commit("Resize Ability Nodes", before, after)
	return ""


func add_frame(title: String, position: Vector2, size: Vector2 = Vector2(360, 220)) -> String:
	if _resource == null:
		return "graph_resource_missing"
	var before: Dictionary = _resource.document_snapshot()
	var after: Dictionary = before.duplicate(true)
	var frame_id := "frame_1"
	var used: Dictionary = {}
	for frame: Dictionary in before.get("frames", []):
		used[String(frame.get("frame_id", ""))] = true
	while used.has(frame_id):
		frame_id = "frame_%d" % (used.size() + 1)
	var frames: Array[Dictionary] = before.get("frames", []).duplicate(true)
	frames.append({"frame_id": frame_id, "title": title, "position": position, "size": size, "node_ids": []})
	after.frames = frames
	_commit("Add Ability Frame", before, after)
	return frame_id


func edit_frame(frame_id: String, frame_data: Dictionary) -> String:
	if _resource == null:
		return "graph_resource_missing"
	var before: Dictionary = _resource.document_snapshot()
	var after: Dictionary = before.duplicate(true)
	var found := false
	var frames: Array[Dictionary] = []
	for frame: Dictionary in before.get("frames", []):
		var next := frame.duplicate(true)
		if String(frame.get("frame_id", "")) == frame_id:
			next.merge(frame_data, true)
			found = true
		frames.append(next)
	if not found:
		return "unknown_frame"
	after.frames = frames
	_commit("Edit Ability Frame", before, after)
	return ""


func remove_frame(frame_id: String) -> String:
	if _resource == null:
		return "graph_resource_missing"
	var before: Dictionary = _resource.document_snapshot()
	var after: Dictionary = before.duplicate(true)
	var frames: Array[Dictionary] = []
	var found := false
	for frame: Dictionary in before.get("frames", []):
		if String(frame.get("frame_id", "")) == frame_id:
			found = true
		else:
			frames.append(frame)
	if not found:
		return "unknown_frame"
	after.frames = frames
	_commit("Delete Ability Frame", before, after)
	return ""


func commit_node_positions(positions: Dictionary) -> String:
	if _resource == null:
		return "graph_resource_missing"
	var before: Dictionary = _resource.document_snapshot()
	var after: Dictionary = before.duplicate(true)
	for node_data: Dictionary in after.nodes:
		if positions.has(node_data.node_id):
			node_data.position = positions[node_data.node_id]
	_commit("Move Ability Nodes", before, after)
	return ""


func copy_payload(node_ids: Array[String]) -> Dictionary:
	if _resource == null:
		return {}
	var selected: Dictionary = {}
	var snapshot: Dictionary = _resource.document_snapshot()
	var payload_nodes: Array[Dictionary] = []
	for node_id: String in node_ids:
		selected[node_id] = true
	for node_data: Dictionary in snapshot.nodes:
		if selected.has(String(node_data.node_id)):
			payload_nodes.append(node_data.duplicate(true))
	var payload_connections: Array[Dictionary] = []
	for connection: Dictionary in snapshot.connections:
		if selected.has(String(connection.from_node_id)) and selected.has(String(connection.to_node_id)):
			payload_connections.append(connection.duplicate(true))
	return {"schema_version": 1, "nodes": payload_nodes, "connections": payload_connections}


func paste_payload(payload: Dictionary, position_offset: Vector2) -> Array[String]:
	if _resource == null or payload.get("schema_version", 0) != 1:
		return []
	var before: Dictionary = _resource.document_snapshot()
	var after: Dictionary = before.duplicate(true)
	var existing: Dictionary = {}
	for node_data: Dictionary in before.nodes:
		existing[String(node_data.node_id)] = true
	var remap: Dictionary = {}
	var pasted_ids: Array[String] = []
	for source_node: Dictionary in payload.get("nodes", []):
		var old_id := String(source_node.node_id)
		var new_id := old_id + "_copy"
		var suffix := 2
		while existing.has(new_id):
			new_id = "%s_%d" % [old_id, suffix]
			suffix += 1
		existing[new_id] = true
		remap[old_id] = new_id
		var copied := source_node.duplicate(true)
		copied.node_id = new_id
		copied.position = copied.position + position_offset
		after.nodes.append(copied)
		pasted_ids.append(new_id)
	for source_connection: Dictionary in payload.get("connections", []):
		if remap.has(source_connection.from_node_id) and remap.has(source_connection.to_node_id):
			var copied_connection := source_connection.duplicate(true)
			copied_connection.from_node_id = remap[source_connection.from_node_id]
			copied_connection.to_node_id = remap[source_connection.to_node_id]
			after.connections.append(copied_connection)
	_commit("Paste Ability Nodes", before, after)
	return pasted_ids


func compile(action_registry: RefCounted) -> RefCounted:
	if _resource == null:
		return CompileResultScript.rejected("graph_resource_missing")
	var schema_error: String = _resource.schema_error()
	if not schema_error.is_empty():
		return CompileResultScript.rejected(schema_error)
	return CompilerScript.new().compile(_resource.to_definition(), _node_registry, action_registry)


func _commit(action_name: String, before: Dictionary, after: Dictionary) -> void:
	if before == after:
		return
	if _undo_redo == null:
		apply_snapshot(after)
		return
	_undo_redo.create_action(action_name)
	_undo_redo.add_do_reference(self)
	_undo_redo.add_undo_reference(self)
	if _undo_redo is UndoRedo:
		_undo_redo.add_do_method(Callable(self, "apply_snapshot").bind(after))
		_undo_redo.add_undo_method(Callable(self, "apply_snapshot").bind(before))
	else:
		_undo_redo.add_do_method(self, "apply_snapshot", after)
		_undo_redo.add_undo_method(self, "apply_snapshot", before)
	_undo_redo.commit_action()


func _next_node_id(type_id: String, snapshot: Dictionary) -> String:
	var prefix := type_id.replace("combat.ability.", "").replace(".", "_")
	var used: Dictionary = {}
	for node_data: Dictionary in snapshot.nodes:
		used[String(node_data.node_id)] = true
	var index := 1
	var candidate := "%s_%d" % [prefix, index]
	while used.has(candidate):
		index += 1
		candidate = "%s_%d" % [prefix, index]
	return candidate
