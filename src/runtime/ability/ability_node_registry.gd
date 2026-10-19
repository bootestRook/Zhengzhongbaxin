class_name AbilityNodeRegistry
extends RefCounted

const NodeDescriptorScript = preload("res://src/runtime/ability/ability_node_descriptor.gd")
const PinDescriptorScript = preload("res://src/runtime/ability/ability_pin_descriptor.gd")
const CatalogScript = preload("res://src/runtime/ability/ability_standard_node_catalog.gd")

const ON_CAST_TYPE := "combat.ability.event.on_cast"
const ON_HIT_TYPE := "combat.ability.event.on_hit"
const ON_PROJECTILE_IMPACT_TYPE := "combat.ability.event.on_projectile_impact"
const ON_HIT_RESOLVED_TYPE := "combat.ability.event.on_hit_resolved"
const ON_DAMAGE_APPLIED_TYPE := "combat.ability.event.on_damage_applied"
const ON_KILL_TYPE := "combat.ability.event.on_kill"
const ON_EXPIRE_TYPE := "combat.ability.event.on_expire"
const EXECUTE_ACTION_TYPE := "combat.ability.action.execute"
const DEAL_DAMAGE_TYPE := "combat.ability.action.deal_damage"
const APPLY_EFFECT_TYPE := "combat.ability.action.apply_effect"
const SELECT_TARGET_TYPE := "combat.ability.target.select"
const EMIT_CUE_TYPE := "combat.ability.presentation.emit_cue"
const SEQUENCE_TYPE := "combat.ability.logic.sequence"
const END_TYPE := "combat.ability.logic.end"
const BRANCH_TYPE := "combat.ability.logic.branch"
const DELAY_TYPE := "combat.ability.logic.delay"
const WAIT_EVENT_TYPE := "combat.ability.logic.wait_event"
const REPEAT_TYPE := "combat.ability.logic.repeat"
const READ_ATTRIBUTE_TYPE := "combat.ability.data.read_attribute"
const READ_VARIABLE_TYPE := "combat.ability.data.read_variable"
const WRITE_VARIABLE_TYPE := "combat.ability.data.write_variable"
const SUBGRAPH_CALL_TYPE := "combat.ability.logic.subgraph_call"
const SPAWN_PROJECTILE_TYPE := "combat.ability.action.spawn_projectile"
const MOVE_TYPE := "combat.ability.action.move"
const SUMMON_TYPE := "combat.ability.action.summon"
const AREA_QUERY_TYPE := "combat.ability.target.area_query"

var _descriptors: Dictionary = {}
var _descriptor_cache: Array[RefCounted] = []
var _descriptor_cache_dirty := true


func register_descriptor(descriptor: RefCounted) -> String:
	if descriptor == null or not descriptor.has_method("validate_node"):
		return "invalid_node_descriptor"
	if descriptor.type_id.is_empty():
		return "node_type_id_empty"
	if _descriptors.has(descriptor.type_id):
		return "duplicate_node_type"
	_descriptors[descriptor.type_id] = descriptor
	_descriptor_cache_dirty = true
	return ""


func has_descriptor(type_id: String) -> bool:
	return _descriptors.has(type_id)


func get_descriptor(type_id: String) -> RefCounted:
	return _descriptors.get(type_id)


func descriptors() -> Array[RefCounted]:
	if not _descriptor_cache_dirty:
		var cached: Array[RefCounted] = []
		cached.assign(_descriptor_cache)
		return cached
	var result: Array[RefCounted] = []
	for type_id: String in _descriptors:
		result.append(_descriptors[type_id])
	result.sort_custom(func(left: RefCounted, right: RefCounted) -> bool:
		if left.category != right.category:
			return left.category < right.category
		return left.display_name < right.display_name
	)
	_descriptor_cache = result
	_descriptor_cache_dirty = false
	return result


func descriptors_for_pin(source_pin: RefCounted, target_is_input: bool = true) -> Array[RefCounted]:
	if source_pin == null or not source_pin.has_method("accepts"):
		return []
	var result: Array[RefCounted] = []
	for descriptor: RefCounted in descriptors():
		var pins: Array[String] = descriptor.input_pins if target_is_input else descriptor.output_pins
		for pin_id: String in pins:
			var candidate: RefCounted = descriptor.input_pin(pin_id) if target_is_input else descriptor.output_pin(pin_id)
			var error: String = candidate.accepts(source_pin) if target_is_input else source_pin.accepts(candidate)
			if error.is_empty():
				result.append(descriptor)
				break
	return result


static func create_default() -> AbilityNodeRegistry:
	var registry := AbilityNodeRegistry.new()
	CatalogScript.register_all(registry)
	return registry
