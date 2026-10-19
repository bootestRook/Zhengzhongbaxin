@tool
class_name AbilityGraphConnectionResource
extends Resource

@export var from_node_id: String = ""
@export var from_pin_id: String = ""
@export var to_node_id: String = ""
@export var to_pin_id: String = ""
@export var kind: String = "control"


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


func to_definition() -> RefCounted:
	var definition_script = preload(
		"res://src/runtime/ability/ability_graph_connection_definition.gd"
	)
	return definition_script.new(from_node_id, from_pin_id, to_node_id, to_pin_id, kind)
