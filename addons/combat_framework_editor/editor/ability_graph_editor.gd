@tool
class_name AbilityGraphEditor
extends Control

const GraphEditScript = preload("res://addons/combat_framework_editor/editor/ability_graph_node_view.gd")
const ControllerScript = preload(
	"res://addons/combat_framework_editor/editor/ability_graph_document_controller.gd"
)
const GraphResourceScript = preload("res://src/runtime/ability/ability_graph_resource.gd")
const ActionRegistryScript = preload("res://src/runtime/ability/ability_action_registry.gd")
const PlaceholderResolverScript = preload(
	"res://addons/combat_framework_editor/editor/ability_editor_placeholder_resolver.gd"
)

@onready var _graph_edit: GraphEdit = $Root/Body/GraphEdit
@onready var _search: LineEdit = $Root/Body/CatalogPanel/Search
@onready var _catalog_filter: OptionButton = $Root/Body/CatalogPanel/CatalogFilter
@onready var _favorite_button: Button = $Root/Body/CatalogPanel/FavoriteButton
@onready var _catalog: ItemList = $Root/Body/CatalogPanel/Catalog
@onready var _status: Label = $Root/Toolbar/Status
@onready var _selected_label: Label = $Root/Body/InspectorPanel/SelectedNode
@onready var _action_id: LineEdit = $Root/Body/InspectorPanel/ActionId
@onready var _apply_action: Button = $Root/Body/InspectorPanel/ApplyAction
@onready var _parameters_json: TextEdit = $Root/Body/InspectorPanel/ParametersJson
@onready var _apply_parameters: Button = $Root/Body/InspectorPanel/ApplyParameters
@onready var _comment: LineEdit = $Root/Body/InspectorPanel/Comment
@onready var _apply_comment: Button = $Root/Body/InspectorPanel/ApplyComment
@onready var _fields: VBoxContainer = $Root/Body/InspectorPanel/Fields
@onready var _diagnostics: ItemList = $Root/Body/InspectorPanel/Diagnostics
@onready var _trace: ItemList = $Root/Body/InspectorPanel/Trace
@onready var _event_trace: ItemList = $Root/Body/InspectorPanel/EventTrace
@onready var _candidate_menu: PopupMenu = $CandidateMenu

var _controller: RefCounted
var _resource: RefCounted
var _action_registry: RefCounted
var _wired := false
var _selected_node_id := ""
var _move_before: Dictionary = {}
var _views: Dictionary = {}
var _debug_node_id := ""
var _debug_snapshot: Dictionary = {}
var _connection_source_node := ""
var _connection_source_port := -1
var _connection_is_output := true
var _candidate_position := Vector2.ZERO
var _favorite_type_ids: Dictionary = {}
var _recent_type_ids: Array[String] = []


func _ready() -> void:
	_wire_ui()
	_catalog_filter.add_item("All")
	_catalog_filter.add_item("Favorites")
	_catalog_filter.add_item("Recent")
	_refresh_catalog()
	_set_status("No graph selected")


func initialize(undo_redo: Object, framework_registry: RefCounted = null) -> void:
	if _controller == null:
		_controller = ControllerScript.new(undo_redo)
		_controller.document_changed.connect(_on_document_changed)
	_action_registry = ActionRegistryScript.new()
	if framework_registry != null and framework_registry.has_method("register_manifest"):
		_controller.set_node_registry(framework_registry.node_registry)
		_action_registry = framework_registry.action_registry
	_action_registry.register_action("editor.placeholder", PlaceholderResolverScript.new())
	_action_registry.register_action("module.damage.deal", PlaceholderResolverScript.new())
	_action_registry.register_action("module.effect.apply", PlaceholderResolverScript.new())
	_refresh_catalog()


func set_graph_resource(graph_resource: RefCounted) -> void:
	if _controller == null:
		initialize(null)
	_resource = graph_resource
	_controller.set_resource(graph_resource)
	_selected_node_id = ""
	_refresh()


func clear_graph_resource() -> void:
	_resource = null
	if _controller != null:
		_controller.set_resource(null)
	_refresh()


func apply_debug_snapshot(snapshot: Dictionary) -> void:
	_debug_snapshot = snapshot.duplicate(true)
	_trace.clear()
	_event_trace.clear()
	for entry: Dictionary in _debug_snapshot.get("trace", []):
		var data: Dictionary = entry.get("data", {})
		_trace.add_item("%03d  %s → %s" % [int(entry.get("sequence", 0)), String(data.get("from_node_id", "")), String(data.get("to_node_id", ""))])
	for entry: Dictionary in _debug_snapshot.get("event_trace", []):
		_event_trace.add_item("%s  tick:%d  %s" % [String(entry.get("event_type", "")), int(entry.get("logical_tick", 0)), String(entry.get("error_code", ""))])
	_debug_node_id = String(snapshot.get("current_node_id", ""))
	_set_status(
		"Run %s / %s / %s%s" % [
			String(snapshot.get("run_id", "")),
			String(snapshot.get("state", "")),
			_debug_node_id,
			(" / wait:%s" % String(snapshot.get("waiting_reason", ""))) if not String(snapshot.get("waiting_reason", "")).is_empty() else "",
		]
	)
	for node_id: String in _views:
		_views[node_id].modulate = Color.WHITE if node_id != _debug_node_id else Color(1.0, 0.82, 0.35, 1.0)
	_apply_debug_connection_activity()
	_select_trace_for_node(_debug_node_id)


func _on_trace_selected(index: int) -> void:
	var entries: Array = _debug_snapshot.get("trace", [])
	if index < 0 or index >= entries.size():
		return
	var data: Dictionary = entries[index].get("data", {})
	_debug_node_id = String(data.get("to_node_id", data.get("from_node_id", "")))
	_debug_snapshot["current_node_id"] = _debug_node_id
	for node_id: String in _views:
		_views[node_id].modulate = Color.WHITE if node_id != _debug_node_id else Color(1.0, 0.82, 0.35, 1.0)
	_apply_debug_connection_activity()


func _select_trace_for_node(node_id: String) -> void:
	if node_id.is_empty():
		return
	var entries: Array = _debug_snapshot.get("trace", [])
	for index in range(entries.size() - 1, -1, -1):
		var data: Dictionary = entries[index].get("data", {})
		if String(data.get("to_node_id", "")) == node_id or String(data.get("from_node_id", "")) == node_id:
			_trace.select(index)
			return


func _wire_ui() -> void:
	if _wired:
		return
	_wired = true
	$Root/Toolbar/CompileButton.pressed.connect(_compile)
	$Root/Toolbar/FrameButton.pressed.connect(_add_frame)
	$Root/Body/InspectorPanel/ApplyAction.pressed.connect(_apply_selected_action)
	$Root/Body/InspectorPanel/ApplyParameters.pressed.connect(_apply_selected_parameters)
	$Root/Body/InspectorPanel/ApplyComment.pressed.connect(_apply_selected_comment)
	_search.text_changed.connect(func(_text: String) -> void: _refresh_catalog())
	_catalog_filter.item_selected.connect(func(_index: int) -> void: _refresh_catalog())
	_favorite_button.pressed.connect(_toggle_catalog_favorite)
	_catalog.item_selected.connect(_on_catalog_item_selected)
	_graph_edit.connection_request.connect(_on_connection_request)
	_graph_edit.disconnection_request.connect(_on_disconnection_request)
	_graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	_graph_edit.begin_node_move.connect(_on_begin_node_move)
	_graph_edit.end_node_move.connect(_on_end_node_move)
	_graph_edit.node_selected.connect(_on_node_selected)
	_graph_edit.node_deselected.connect(_on_node_deselected)
	_graph_edit.copy_nodes_request.connect(_copy_selected)
	_graph_edit.cut_nodes_request.connect(_cut_selected)
	_graph_edit.paste_nodes_request.connect(_paste_clipboard)
	_graph_edit.duplicate_nodes_request.connect(_duplicate_selected)
	_graph_edit.scroll_offset_changed.connect(_on_scroll_changed)
	_graph_edit.popup_request.connect(_on_graph_popup_request)
	_graph_edit.connection_drag_started.connect(_on_connection_drag_started)
	_graph_edit.connection_drag_ended.connect(_on_connection_drag_ended)
	_candidate_menu.id_pressed.connect(_on_candidate_selected)
	_trace.item_selected.connect(_on_trace_selected)


func _refresh() -> void:
	if not is_node_ready():
		return
	_graph_edit.clear_connections()
	for child: Node in _graph_edit.get_children():
		if child is GraphNode or child is GraphFrame:
			_graph_edit.remove_child(child)
			child.queue_free()
	_views.clear()
	for frame_data: Dictionary in _resource.frames if _resource != null else []:
		var frame := GraphFrame.new()
		frame.name = String(frame_data.get("frame_id", "frame"))
		frame.title = String(frame_data.get("title", "Frame"))
		frame.position_offset = frame_data.get("position", Vector2.ZERO)
		frame.size = frame_data.get("size", Vector2(360, 220))
		_graph_edit.add_child(frame)
		_graph_edit.move_child(frame, 0)
	if _resource == null:
		_selected_label.text = "No node selected"
		_action_id.text = ""
		_parameters_json.text = "{}"
		_apply_action.disabled = true
		_apply_parameters.disabled = true
		return
	_graph_edit.scroll_offset = _resource.editor_scroll_offset
	_graph_edit.zoom = _resource.editor_zoom
	for node: RefCounted in _resource.nodes:
		var descriptor: RefCounted = _controller.descriptor(node.type_id)
		var view := GraphEditScript.new()
		view.configure(node.to_definition(), descriptor)
		view.position_offset = _resource.node_position(node.node_id)
		view.custom_minimum_size = _resource.node_size(node.node_id)
		view.set_comment(_resource.node_comment(node.node_id))
		_graph_edit.add_child(view)
		_views[node.node_id] = view
	for connection: RefCounted in _resource.connections:
		var from_view: AbilityGraphNodeView = _views.get(connection.from_node_id) as AbilityGraphNodeView
		var to_view: AbilityGraphNodeView = _views.get(connection.to_node_id) as AbilityGraphNodeView
		if from_view == null or to_view == null:
			continue
		var from_port := _output_port(from_view, connection.from_pin_id)
		var to_port := _input_port(to_view, connection.to_pin_id)
		if from_port >= 0 and to_port >= 0:
			_graph_edit.connect_node(connection.from_node_id, from_port, connection.to_node_id, to_port)
	_apply_debug_connection_activity()
	if _views.has(_selected_node_id):
		_views[_selected_node_id].selected = true
	_update_inspector()


func _refresh_catalog() -> void:
	if not is_node_ready() or _controller == null:
		return
	_catalog.clear()
	var query := _search.text.strip_edges().to_lower()
	var filter := _catalog_filter.get_item_text(_catalog_filter.selected) if _catalog_filter.item_count > 0 else "All"
	for descriptor: RefCounted in _controller.node_registry().descriptors():
		var haystack := "%s %s %s %s" % [
			descriptor.display_name,
			descriptor.type_id,
			descriptor.category,
			" ".join(descriptor.keywords),
		]
		if not query.is_empty() and not haystack.to_lower().contains(query):
			continue
		if filter == "Favorites" and not _favorite_type_ids.has(descriptor.type_id):
			continue
		if filter == "Recent" and not _recent_type_ids.has(descriptor.type_id):
			continue
		var marker := "★ " if _favorite_type_ids.has(descriptor.type_id) else ""
		var index := _catalog.add_item("%s%s / %s" % [marker, descriptor.category, descriptor.display_name])
		_catalog.set_item_metadata(index, descriptor.type_id)


func _toggle_catalog_favorite() -> void:
	var selected := _catalog.get_selected_items()
	if selected.is_empty():
		return
	var type_id := String(_catalog.get_item_metadata(selected[0]))
	if _favorite_type_ids.has(type_id):
		_favorite_type_ids.erase(type_id)
	else:
		_favorite_type_ids[type_id] = true
	_refresh_catalog()


func _apply_debug_connection_activity() -> void:
	if _resource == null:
		return
	var active: Dictionary = _debug_snapshot.get("active_edge", {})
	for connection: RefCounted in _resource.connections:
		var from_view: AbilityGraphNodeView = _views.get(connection.from_node_id) as AbilityGraphNodeView
		var to_view: AbilityGraphNodeView = _views.get(connection.to_node_id) as AbilityGraphNodeView
		if from_view == null or to_view == null:
			continue
		var from_port := _output_port(from_view, connection.from_pin_id)
		var to_port := _input_port(to_view, connection.to_pin_id)
		if from_port < 0 or to_port < 0:
			continue
		var is_active: bool = (
			String(active.get("from_node_id", "")) == connection.from_node_id
			and String(active.get("output_pin", "")) == connection.from_pin_id
			and String(active.get("to_node_id", "")) == connection.to_node_id
		)
		_graph_edit.set_connection_activity(connection.from_node_id, from_port, connection.to_node_id, to_port, 1.0 if is_active else 0.0)


func _on_catalog_item_selected(index: int) -> void:
	if _resource == null:
		return
	var type_id := String(_catalog.get_item_metadata(index))
	_recent_type_ids.erase(type_id)
	_recent_type_ids.push_front(type_id)
	while _recent_type_ids.size() > 12:
		_recent_type_ids.pop_back()
	var result: String = _controller.add_node(type_id, _graph_edit.scroll_offset + Vector2(240, 160))
	if not result.is_empty():
		_set_status("Add failed: %s" % result)


func _on_connection_drag_started(from_node: StringName, from_port: int, is_output: bool) -> void:
	_connection_source_node = String(from_node)
	_connection_source_port = from_port
	_connection_is_output = is_output


func _on_connection_drag_ended() -> void:
	_connection_source_node = ""
	_connection_source_port = -1


func _on_graph_popup_request(at_position: Vector2) -> void:
	if _resource == null or _controller == null:
		return
	_candidate_position = at_position
	_candidate_menu.clear()
	var candidates := _candidate_descriptors()
	for descriptor: RefCounted in candidates:
		var index := _candidate_menu.item_count
		_candidate_menu.add_item("%s / %s" % [descriptor.category, descriptor.display_name])
		_candidate_menu.set_item_metadata(index, descriptor.type_id)
	if _candidate_menu.item_count == 0:
		return
	var global_position: Vector2 = _graph_edit.get_global_transform_with_canvas() * at_position
	_candidate_menu.popup_on_parent(Rect2i(Vector2i(global_position), Vector2i.ZERO))


func _candidate_descriptors() -> Array[RefCounted]:
	if _connection_source_node.is_empty() or _connection_source_port < 0:
		return _controller.node_registry().descriptors()
	var source_view := _views.get(_connection_source_node) as AbilityGraphNodeView
	if source_view == null:
		return _controller.node_registry().descriptors()
	var source_node: RefCounted = _resource.node_by_id(_connection_source_node)
	var source_descriptor: RefCounted = _controller.descriptor(source_node.type_id)
	var source_pin_id := source_view.output_pin_for_port(_connection_source_port) if _connection_is_output else source_view.input_pin_for_port(_connection_source_port)
	if source_pin_id.is_empty() or source_descriptor == null:
		return []
	var source_pin: RefCounted = source_descriptor.output_pin(source_pin_id) if _connection_is_output else source_descriptor.input_pin(source_pin_id)
	return _controller.node_registry().descriptors_for_pin(source_pin, not _connection_is_output)


func _on_candidate_selected(index: int) -> void:
	var type_id := String(_candidate_menu.get_item_metadata(index))
	var new_node_id: String = _controller.add_node(type_id, _candidate_position)
	if new_node_id.is_empty() or _connection_source_node.is_empty():
		return
	_connect_candidate(new_node_id)


func _connect_candidate(new_node_id: String) -> void:
	var source_node: RefCounted = _resource.node_by_id(_connection_source_node)
	var target_node: RefCounted = _resource.node_by_id(new_node_id)
	if source_node == null or target_node == null:
		return
	var source_descriptor: RefCounted = _controller.descriptor(source_node.type_id)
	var target_descriptor: RefCounted = _controller.descriptor(target_node.type_id)
	var source_view := _views.get(_connection_source_node) as AbilityGraphNodeView
	if source_descriptor == null or target_descriptor == null or source_view == null:
		return
	var source_pin_id := source_view.output_pin_for_port(_connection_source_port) if _connection_is_output else source_view.input_pin_for_port(_connection_source_port)
	if source_pin_id.is_empty():
		return
	if _connection_is_output:
		var source_pin: RefCounted = source_descriptor.output_pin(source_pin_id)
		for pin_id: String in target_descriptor.input_pins:
			if target_descriptor.input_pin(pin_id).accepts(source_pin).is_empty():
				_controller.connect_nodes(_connection_source_node, source_pin_id, new_node_id, pin_id)
				return
	else:
		var source_pin: RefCounted = source_descriptor.input_pin(source_pin_id)
		for pin_id: String in target_descriptor.output_pins:
			if source_pin.accepts(target_descriptor.output_pin(pin_id)).is_empty():
				_controller.connect_nodes(new_node_id, pin_id, _connection_source_node, source_pin_id)
				return


func _on_connection_request(
	from_node: StringName,
	from_port: int,
	to_node: StringName,
	to_port: int
) -> void:
	var source_view: AbilityGraphNodeView = _views.get(String(from_node)) as AbilityGraphNodeView
	var target_view: AbilityGraphNodeView = _views.get(String(to_node)) as AbilityGraphNodeView
	if source_view == null or target_view == null:
		return
	var output_pin := source_view.output_pin_for_port(from_port)
	var input_pin := target_view.input_pin_for_port(to_port)
	if output_pin.is_empty() or input_pin.is_empty():
		var swapped_source: AbilityGraphNodeView = _views.get(String(to_node)) as AbilityGraphNodeView
		var swapped_target: AbilityGraphNodeView = _views.get(String(from_node)) as AbilityGraphNodeView
		if swapped_source != null and swapped_target != null:
			output_pin = swapped_source.output_pin_for_port(to_port)
			input_pin = swapped_target.input_pin_for_port(from_port)
			if not output_pin.is_empty() and not input_pin.is_empty():
				var swapped_result: String = _controller.connect_nodes(
					String(to_node), output_pin, String(from_node), input_pin
				)
				if not swapped_result.is_empty():
					_set_status("Connect failed: %s" % swapped_result)
				return
		_set_status("Connect failed: ports must be output → input")
		return
	var result: String = _controller.connect_nodes(String(from_node), output_pin, String(to_node), input_pin)
	if not result.is_empty():
		_set_status("Connect failed: %s" % result)


func _on_disconnection_request(
	from_node: StringName,
	from_port: int,
	to_node: StringName,
	to_port: int
) -> void:
	var source_view: AbilityGraphNodeView = _views.get(String(from_node)) as AbilityGraphNodeView
	var target_view: AbilityGraphNodeView = _views.get(String(to_node)) as AbilityGraphNodeView
	if source_view == null or target_view == null:
		return
	var output_pin := source_view.output_pin_for_port(from_port)
	var input_pin := target_view.input_pin_for_port(to_port)
	var source_id := String(from_node)
	var target_id := String(to_node)
	if output_pin.is_empty() or input_pin.is_empty():
		output_pin = target_view.output_pin_for_port(to_port)
		input_pin = source_view.input_pin_for_port(from_port)
		source_id = String(to_node)
		target_id = String(from_node)
	var result: String = _controller.disconnect_nodes(source_id, output_pin, target_id, input_pin)
	if not result.is_empty():
		_set_status("Disconnect failed: %s" % result)


func _on_delete_nodes_request(node_names: Array[StringName]) -> void:
	var ids: Array[String] = []
	for node_name: StringName in node_names:
		ids.append(String(node_name))
	_controller.delete_nodes(ids)
	_selected_node_id = ""


func _on_begin_node_move() -> void:
	_move_before.clear()
	if _resource == null:
		return
	for node: RefCounted in _resource.nodes:
		_move_before[node.node_id] = _resource.node_position(node.node_id)


func _on_end_node_move() -> void:
	if _resource == null or _move_before.is_empty():
		return
	var positions: Dictionary = {}
	for node_id: String in _views:
		positions[node_id] = _views[node_id].position_offset
	if positions != _move_before:
		_controller.commit_node_positions(positions)
	_move_before.clear()


func _on_node_selected(node: Node) -> void:
	if node is AbilityGraphNodeView:
		_selected_node_id = node.source_node_id
		_update_inspector()


func _on_node_deselected(_node: Node) -> void:
	if not _views.has(_selected_node_id):
		_selected_node_id = ""
		_update_inspector()


func _update_inspector() -> void:
	if _resource == null or not _views.has(_selected_node_id):
		_selected_label.text = "No node selected"
		_action_id.text = ""
		_comment.text = ""
		_clear_parameter_fields()
		_action_id.editable = false
		_apply_action.disabled = true
		return
	var node: RefCounted = _resource.node_by_id(_selected_node_id)
	_selected_label.text = "%s\n%s" % [_selected_node_id, node.type_id]
	var selected_descriptor: RefCounted = _controller.descriptor(node.type_id)
	var is_action: bool = selected_descriptor != null and selected_descriptor.operation_kind == "action"
	_action_id.editable = is_action
	_apply_action.disabled = not is_action
	_action_id.text = String(node.parameters.get("action_id", ""))
	_comment.text = _resource.node_comment(_selected_node_id)
	_parameters_json.text = JSON.stringify(node.parameters, "  ")
	_apply_parameters.disabled = false
	_rebuild_parameter_fields(selected_descriptor, node.parameters)


func _apply_selected_action() -> void:
	if _selected_node_id.is_empty():
		return
	var result: String = _controller.edit_action_id(_selected_node_id, _action_id.text.strip_edges())
	if not result.is_empty():
		_set_status("Edit failed: %s" % result)


func _apply_selected_parameters() -> void:
	if _selected_node_id.is_empty():
		return
	var parsed: Variant = JSON.parse_string(_parameters_json.text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_set_status("Parameters must be a JSON object")
		return
	var result: String = _controller.edit_parameters(_selected_node_id, parsed)
	if not result.is_empty():
		_set_status("Edit failed: %s" % result)


func _apply_selected_comment() -> void:
	if _selected_node_id.is_empty():
		return
	var result: String = _controller.edit_comment(_selected_node_id, _comment.text)
	if not result.is_empty():
		_set_status("Edit failed: %s" % result)


func _add_frame() -> void:
	if _resource == null:
		return
	var frame_id: String = _controller.add_frame("Ability Frame", _graph_edit.scroll_offset + Vector2(120, 100))
	_set_status("Added %s" % frame_id)


func _clear_parameter_fields() -> void:
	for child: Node in _fields.get_children():
		child.queue_free()


func _rebuild_parameter_fields(descriptor: RefCounted, parameters: Dictionary) -> void:
	_clear_parameter_fields()
	if descriptor == null:
		return
	for field: Dictionary in descriptor.parameter_fields():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = String(field.get("label", field.get("field_id", "Field")))
		label.custom_minimum_size = Vector2(90, 0)
		row.add_child(label)
		var control: Control = _create_field_control(field, parameters.get(field.get("field_id", ""), null))
		if control == null:
			continue
		control.set_meta("ability_field_id", String(field.get("field_id", "")))
		row.add_child(control)
		_fields.add_child(row)


func _create_field_control(field: Dictionary, value: Variant) -> Control:
	match String(field.get("type", "string")):
		"number":
			var spin := SpinBox.new()
			spin.min_value = float(field.get("min", -100000.0))
			spin.max_value = float(field.get("max", 100000.0))
			spin.step = float(field.get("step", 0.1))
			spin.value = float(value) if value != null else 0.0
			spin.value_changed.connect(func(next_value: float) -> void: _apply_field_value(spin, next_value))
			return spin
		"bool":
			var check := CheckButton.new()
			check.button_pressed = bool(value)
			check.toggled.connect(func(next_value: bool) -> void: _apply_field_value(check, next_value))
			return check
		"enum":
			var option := OptionButton.new()
			for enum_value: String in field.get("enum_values", []):
				option.add_item(enum_value)
				if enum_value == String(value):
					option.select(option.item_count - 1)
			option.item_selected.connect(func(index: int) -> void: _apply_field_value(option, option.get_item_text(index)))
			return option
		"definition_ref":
			var definition_line := LineEdit.new()
			var definition_kind := String(field.get("definition_kind", "definition"))
			definition_line.placeholder_text = "<%s definition id>" % definition_kind
			definition_line.tooltip_text = "Stable %s Definition ID" % definition_kind
			definition_line.text = String(value) if value != null else ""
			definition_line.text_submitted.connect(func(next_value: String) -> void: _apply_field_value(definition_line, next_value))
			definition_line.focus_exited.connect(func() -> void: _apply_field_value(definition_line, definition_line.text))
			return definition_line
		_:
			var line := LineEdit.new()
			line.text = String(value) if value != null else ""
			line.text_submitted.connect(func(next_value: String) -> void: _apply_field_value(line, next_value))
			line.focus_exited.connect(func() -> void: _apply_field_value(line, line.text))
			return line


func _apply_field_value(control: Control, value: Variant) -> void:
	if _selected_node_id.is_empty() or _resource == null:
		return
	var field_id := String(control.get_meta("ability_field_id", ""))
	if field_id.is_empty():
		return
	var node: RefCounted = _resource.node_by_id(_selected_node_id)
	var parameters: Dictionary = node.parameters.duplicate(true)
	parameters[field_id] = value
	var result: String = _controller.edit_parameters(_selected_node_id, parameters)
	if not result.is_empty():
		_set_status("Edit failed: %s" % result)


func _compile() -> void:
	_diagnostics.clear()
	if _resource == null:
		_set_status("No graph selected")
		return
	var result: RefCounted = _controller.compile(_action_registry)
	if result.accepted:
		_set_status("Compiled %s (%d operations)" % [_resource.graph_id, result.plan.operation_count()])
		_diagnostics.add_item("OK: execution plan is valid")
		return
	var location: String = result.node_id
	if not result.pin_id.is_empty():
		location += ":%s" % result.pin_id
	_diagnostics.add_item("ERROR %s %s" % [result.error_code, location])
	_set_status("Compile failed: %s" % result.error_code)


func _copy_selected() -> void:
	if _resource == null:
		return
	var selected: Array[String] = _selected_node_ids()
	DisplayServer.clipboard_set(JSON.stringify(_controller.copy_payload(selected)))
	_set_status("Copied %d node(s)" % selected.size())


func _cut_selected() -> void:
	_copy_selected()
	var selected := _selected_node_ids()
	_controller.delete_nodes(selected)
	_selected_node_id = ""


func _paste_clipboard() -> void:
	var parsed: Variant = JSON.parse_string(DisplayServer.clipboard_get())
	if typeof(parsed) != TYPE_DICTIONARY:
		_set_status("Clipboard does not contain an Ability Graph payload")
		return
	var pasted: Array[String] = _controller.paste_payload(parsed, Vector2(40, 40))
	if pasted.is_empty():
		_set_status("Nothing pasted")
		return
	_selected_node_id = pasted[0]
	_set_status("Pasted %d node(s)" % pasted.size())


func _duplicate_selected() -> void:
	var payload: Dictionary = _controller.copy_payload(_selected_node_ids())
	var pasted: Array[String] = _controller.paste_payload(payload, Vector2(40, 40))
	if not pasted.is_empty():
		_selected_node_id = pasted[0]


func _selected_node_ids() -> Array[String]:
	var ids: Array[String] = []
	for node_id: String in _views:
		if _views[node_id].selected:
			ids.append(node_id)
	return ids


func _on_scroll_changed(offset: Vector2) -> void:
	if _resource != null:
		_resource.editor_scroll_offset = offset


func _on_document_changed() -> void:
	_refresh()


func _set_status(message: String) -> void:
	if is_node_ready():
		_status.text = message


func _input_port(view: AbilityGraphNodeView, pin_id: String) -> int:
	for port_index in range(view.get_input_port_count()):
		if view.input_pin_for_port(port_index) == pin_id:
			return port_index
	return -1


func _output_port(view: AbilityGraphNodeView, pin_id: String) -> int:
	for port_index in range(view.get_output_port_count()):
		if view.output_pin_for_port(port_index) == pin_id:
			return port_index
	return -1


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed:
		return
	if event.ctrl_pressed and event.keycode == KEY_S:
		get_viewport().set_input_as_handled()
		_compile()
