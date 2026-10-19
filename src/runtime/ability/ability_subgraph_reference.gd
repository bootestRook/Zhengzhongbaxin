class_name AbilitySubgraphReference
extends RefCounted

var graph_id: String = ""
var input_types: Dictionary = {}
var output_types: Dictionary = {}


func _init(
	referenced_graph_id: String = "",
	referenced_inputs: Dictionary = {},
	referenced_outputs: Dictionary = {}
) -> void:
	graph_id = referenced_graph_id
	input_types = referenced_inputs.duplicate(true)
	output_types = referenced_outputs.duplicate(true)


func validate() -> String:
	if graph_id.is_empty():
		return "subgraph_id_empty"
	for pin_id: String in input_types:
		if pin_id.is_empty() or String(input_types[pin_id]).is_empty():
			return "subgraph_input_contract_invalid"
	for pin_id: String in output_types:
		if pin_id.is_empty() or String(output_types[pin_id]).is_empty():
			return "subgraph_output_contract_invalid"
	return ""


func to_dictionary() -> Dictionary:
	return {"graph_id": graph_id, "input_types": input_types.duplicate(true), "output_types": output_types.duplicate(true)}
