class_name DamageComponent
extends RefCounted

var damage_type_id: String = "physical"
var amount: float = 0.0
var duration_ticks: int = 0
var tags: Array[String] = []


func _init(
	configured_damage_type_id: String = "physical",
	configured_amount: float = 0.0,
	configured_duration_ticks: int = 0,
	configured_tags: Array[String] = []
) -> void:
	damage_type_id = configured_damage_type_id
	amount = configured_amount
	duration_ticks = configured_duration_ticks
	tags = configured_tags.duplicate()


func validate() -> String:
	if damage_type_id.is_empty():
		return "damage_type_id_empty"
	if amount < 0.0 or amount == INF or amount == -INF or amount != amount:
		return "damage_component_amount_invalid"
	if duration_ticks < 0:
		return "damage_component_duration_invalid"
	return ""


func snapshot() -> Dictionary:
	return {
		"damage_type_id": damage_type_id,
		"amount": amount,
		"duration_ticks": duration_ticks,
		"tags": tags.duplicate(),
	}
