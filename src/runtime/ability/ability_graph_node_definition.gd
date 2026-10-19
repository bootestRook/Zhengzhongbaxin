class_name AbilityGraphNodeDefinition
extends RefCounted

var node_id: String = ""
var type_id: String = ""
var configuration: RefCounted


func _init(
	definition_node_id: String = "",
	definition_type_id: String = "",
	definition_configuration: RefCounted = null
) -> void:
	node_id = definition_node_id
	type_id = definition_type_id
	configuration = definition_configuration
