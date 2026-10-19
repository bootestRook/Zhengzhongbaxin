class_name AbilityPlanOperation
extends RefCounted

var node_id: String = ""
var kind: String = ""
var action_id: String = ""
var default_output_pin: String = ""
var parameters: Dictionary = {}


func _init(
	operation_node_id: String = "",
	operation_kind: String = "",
	operation_action_id: String = "",
	output_pin_id: String = "",
	operation_parameters: Dictionary = {}
) -> void:
	node_id = operation_node_id
	kind = operation_kind
	action_id = operation_action_id
	default_output_pin = output_pin_id
	parameters = operation_parameters.duplicate(true)
