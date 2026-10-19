@tool
class_name AbilityGraphNodeView
extends GraphNode

const PIN_COLOR := Color(0.36, 0.68, 0.95, 1.0)

var source_node_id: String = ""
var _input_pin_ids: Array[String] = []
var _output_pin_ids: Array[String] = []


func configure(node_data: RefCounted, descriptor: RefCounted) -> void:
	source_node_id = node_data.node_id
	name = source_node_id
	title = descriptor.display_name if descriptor != null else "Missing: %s" % node_data.type_id
	_input_pin_ids = descriptor.input_pins.duplicate() if descriptor != null else []
	_output_pin_ids = descriptor.output_pins.duplicate() if descriptor != null else []
	var row_count := maxi(_input_pin_ids.size(), _output_pin_ids.size())
	for slot_index in range(row_count):
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(180, 24)
		var input_label := Label.new()
		input_label.text = _input_pin_ids[slot_index] if slot_index < _input_pin_ids.size() else ""
		input_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(input_label)
		var output_label := Label.new()
		output_label.text = _output_pin_ids[slot_index] if slot_index < _output_pin_ids.size() else ""
		output_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		output_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(output_label)
		add_child(row)
		var has_input := slot_index < _input_pin_ids.size()
		var has_output := slot_index < _output_pin_ids.size()
		var input_type := _pin_slot_type(descriptor.input_pin(_input_pin_ids[slot_index])) if has_input else 0
		var output_type := _pin_slot_type(descriptor.output_pin(_output_pin_ids[slot_index])) if has_output else 0
		set_slot(slot_index, has_input, input_type, _pin_color(input_type), has_output, output_type, _pin_color(output_type))
		if has_input:
			set_slot_metadata_left(slot_index, _input_pin_ids[slot_index])
		if has_output:
			set_slot_metadata_right(slot_index, _output_pin_ids[slot_index])
	if descriptor != null and descriptor.operation_kind == "action":
		var action_label := Label.new()
		action_label.text = "Action: %s" % String(node_data.configuration.action_id)
		action_label.modulate = Color(0.72, 0.78, 0.88, 1.0)
		add_child(action_label)


func set_comment(comment: String) -> void:
	var label := get_node_or_null("Comment") as Label
	if label == null:
		label = Label.new()
		label.name = "Comment"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.modulate = Color(0.62, 0.68, 0.78, 1.0)
		add_child(label)
	label.text = comment
	label.visible = not comment.is_empty()


func input_pin_for_port(port_index: int) -> String:
	var slot_index := get_input_port_slot(port_index)
	return String(get_slot_metadata_left(slot_index))


func output_pin_for_port(port_index: int) -> String:
	var slot_index := get_output_port_slot(port_index)
	return String(get_slot_metadata_right(slot_index))


func _pin_slot_type(pin: RefCounted) -> int:
	if pin == null:
		return 0
	match String(pin.kind):
		"value":
			return 1
		"owned_scope":
			return 2
	return 0


func _pin_color(slot_type: int) -> Color:
	match slot_type:
		1:
			return Color(0.55, 0.88, 0.52, 1.0)
		2:
			return Color(0.95, 0.72, 0.38, 1.0)
	return PIN_COLOR
