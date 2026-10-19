class_name DamageSpec
extends RefCounted

const ComponentScript = preload("res://src/runtime/modules/damage/damage_component.gd")

var source_entity_id: String = ""
var instigator_entity_id: String = ""
var target_entity_id: String = ""
var attribute_id: String = "health"
var components: Array[RefCounted] = []
var cause_chain: Array[String] = []
var flags: Array[String] = []
var capture_policy: String = "on_request"


func _init(
	configured_source_entity_id: String = "",
	configured_target_entity_id: String = "",
	configured_amount: float = 0.0,
	configured_attribute_id: String = "health"
) -> void:
	source_entity_id = configured_source_entity_id
	instigator_entity_id = configured_source_entity_id
	target_entity_id = configured_target_entity_id
	attribute_id = configured_attribute_id
	if configured_amount > 0.0:
		components.append(ComponentScript.new("physical", configured_amount))


func add_component(component: RefCounted) -> String:
	if not (component is ComponentScript):
		return "invalid_damage_component"
	var error: String = component.validate()
	if not error.is_empty():
		return error
	components.append(component)
	return ""


func total_amount() -> float:
	var total := 0.0
	for component: RefCounted in components:
		total += component.amount
	return total


func validate() -> String:
	if source_entity_id.is_empty():
		return "damage_source_missing"
	if target_entity_id.is_empty():
		return "damage_target_missing"
	if attribute_id.is_empty():
		return "damage_attribute_id_empty"
	if components.is_empty():
		return "damage_components_empty"
	for component: RefCounted in components:
		if not (component is ComponentScript):
			return "invalid_damage_component"
		var error: String = component.validate()
		if not error.is_empty():
			return error
	return ""


func snapshot() -> Dictionary:
	var component_data: Array[Dictionary] = []
	for component: RefCounted in components:
		component_data.append(component.snapshot())
	return {
		"source_entity_id": source_entity_id,
		"instigator_entity_id": instigator_entity_id,
		"target_entity_id": target_entity_id,
		"attribute_id": attribute_id,
		"components": component_data,
		"cause_chain": cause_chain.duplicate(),
		"flags": flags.duplicate(),
		"capture_policy": capture_policy,
	}
