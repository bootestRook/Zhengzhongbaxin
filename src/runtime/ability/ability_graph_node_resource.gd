@tool
class_name AbilityGraphNodeResource
extends Resource

@export var node_id: String = ""
@export var type_id: String = ""
@export var parameters: Dictionary = {}


func to_definition() -> RefCounted:
	var configuration: RefCounted = null
	if (
		type_id.begins_with("combat.ability.action.")
		or type_id.begins_with("combat.ability.target.")
		or type_id.begins_with("combat.ability.presentation.")
	):
		var config_script = preload(
			"res://src/runtime/ability/ability_action_node_configuration.gd"
		)
		configuration = config_script.new(
			String(parameters.get("action_id", "")),
			parameters
		)
	elif not parameters.is_empty():
		var node_config_script = preload(
			"res://src/runtime/ability/ability_node_configuration.gd"
		)
		configuration = node_config_script.new(parameters)
	var definition_script = preload(
		"res://src/runtime/ability/ability_graph_node_definition.gd"
	)
	return definition_script.new(node_id, type_id, configuration)
