class_name AbilityGraphConnectionDefinition
extends RefCounted

var from_node_id: String = ""
var from_pin_id: String = ""
var to_node_id: String = ""
var to_pin_id: String = ""
var kind: String = "control"


func _init(
	source_node_id: String = "",
	source_pin_id: String = "",
	target_node_id: String = "",
	target_pin_id: String = "",
	connection_kind: String = "control"
) -> void:
	from_node_id = source_node_id
	from_pin_id = source_pin_id
	to_node_id = target_node_id
	to_pin_id = target_pin_id
	kind = connection_kind
