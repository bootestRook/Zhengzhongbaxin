class_name AbilityDefinition
extends RefCounted

var ability_id: String = ""
var graph_id: String = ""
var cooldown_ticks: int = 0
var costs: Dictionary = {}


func _init(
	definition_ability_id: String = "",
	definition_graph_id: String = "",
	definition_cooldown_ticks: int = 0,
	definition_costs: Dictionary = {}
) -> void:
	ability_id = definition_ability_id
	graph_id = definition_graph_id
	cooldown_ticks = definition_cooldown_ticks
	costs = definition_costs.duplicate(true)


func validate() -> String:
	if ability_id.is_empty():
		return "ability_id_empty"
	if graph_id.is_empty():
		return "ability_graph_id_empty"
	if cooldown_ticks < 0:
		return "ability_cooldown_invalid"
	for attribute_id: String in costs:
		if attribute_id.is_empty() or float(costs[attribute_id]) < 0.0:
			return "ability_cost_invalid"
	return ""
