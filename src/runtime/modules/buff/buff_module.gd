class_name BuffModule
extends RefCounted

const DomainEventScript = preload("res://src/runtime/core/core_domain_event.gd")
const ResolverScript = preload("res://src/runtime/modules/buff/buff_action_resolver.gd")

var _state: RefCounted


func _init(state: RefCounted) -> void:
	_state = state


func register_actions(action_registry: RefCounted) -> String:
	if action_registry == null or not action_registry.has_method("register_action"):
		return "buff_action_registry_missing"
	if action_registry.has_action("module.effect.apply"):
		return ""
	return action_registry.register_action("module.effect.apply", ResolverScript.new())


func apply_effect(target_entity_id: String, effect_id: String, source_entity_id: String = "") -> Dictionary:
	var target: RefCounted = _state.entity(target_entity_id)
	if target == null:
		return {"accepted": false, "error_code": "effect_target_missing", "events": []}
	var instance: RefCounted = target.effects.apply(effect_id, source_entity_id, _state.logical_tick, target_entity_id)
	if instance == null:
		return {"accepted": false, "error_code": "unknown_effect", "events": []}
	var event := DomainEventScript.new(
		"effect.applied",
		{
			"effect_id": instance.effect_id,
			"instance_id": instance.instance_id,
			"target_entity_id": target_entity_id,
			"source_entity_id": source_entity_id,
		},
		"",
		_state.logical_tick,
		0,
		source_entity_id,
		[target_entity_id]
	)
	return {"accepted": true, "error_code": "", "instance_id": instance.instance_id, "events": [event]}


func remove_effect(target_entity_id: String, instance_id: String) -> Dictionary:
	var target: RefCounted = _state.entity(target_entity_id)
	if target == null:
		return {"accepted": false, "error_code": "effect_target_missing", "events": []}
	var remove_error: String = target.effects.remove(instance_id)
	if not remove_error.is_empty():
		return {"accepted": false, "error_code": remove_error, "events": []}
	return {
		"accepted": true,
		"error_code": "",
		"events": [DomainEventScript.new("effect.removed", {"instance_id": instance_id}, "", _state.logical_tick, 0, "", [target_entity_id])],
	}
