class_name DamageModule
extends RefCounted

const RequestScript = preload("res://src/runtime/core/core_event_request.gd")
const HandlerScript = preload("res://src/runtime/modules/damage/damage_commit_handler.gd")
const ResolverScript = preload("res://src/runtime/modules/damage/damage_action_resolver.gd")
const SpecScript = preload("res://src/runtime/modules/damage/damage_spec.gd")
const ComponentScript = preload("res://src/runtime/modules/damage/damage_component.gd")
const HitResultScript = preload("res://src/runtime/modules/damage/hit_result.gd")
const HitModuleScript = preload("res://src/runtime/modules/damage/hit_module.gd")
const PipelineResultScript = preload("res://src/runtime/core/core_event_pipeline_result.gd")

var _state: RefCounted
var _pipeline: RefCounted
var _handler_handle: String = ""
var _hit_module: RefCounted = HitModuleScript.new()
var health_attribute_id: String = "health"


func _init(state: RefCounted, pipeline: RefCounted, attribute_id: String = "health") -> void:
	_state = state
	_pipeline = pipeline
	health_attribute_id = attribute_id


func register() -> String:
	if _state == null or _pipeline == null:
		return "damage_module_dependency_missing"
	if not _handler_handle.is_empty():
		return ""
	_handler_handle = _pipeline.register("damage.request", HandlerScript.new(_state))
	return "" if not _handler_handle.is_empty() else "damage_handler_registration_failed"


func unregister() -> String:
	if _handler_handle.is_empty():
		return "damage_handler_not_registered"
	var result: String = _pipeline.unregister("damage.request", _handler_handle)
	if result.is_empty():
		_handler_handle = ""
	return result


func register_actions(action_registry: RefCounted) -> String:
	if action_registry == null or not action_registry.has_method("register_action"):
		return "damage_action_registry_missing"
	if action_registry.has_action("module.damage.deal"):
		return ""
	return action_registry.register_action("module.damage.deal", ResolverScript.new(self, health_attribute_id))


func apply_damage(
	source_entity_id: String,
	target_entity_id: String,
	amount: float,
	cause_chain: Array[String] = []
) -> RefCounted:
	var spec := SpecScript.new(source_entity_id, target_entity_id, amount, health_attribute_id)
	spec.cause_chain = cause_chain.duplicate()
	return apply_spec(spec)


func apply_spec(spec: RefCounted) -> RefCounted:
	if not (spec is SpecScript):
		return PipelineResultScript.rejected("damage_spec_invalid", 0, [])
	var validation_error: String = spec.validate()
	if not validation_error.is_empty():
		return PipelineResultScript.rejected(validation_error, 0, [])
	var component_data: Array[Dictionary] = []
	for component: RefCounted in spec.components:
		component_data.append(component.snapshot())
	var request := RequestScript.new(
		"damage.request",
		{
			"amount": spec.total_amount(),
			"attribute_id": spec.attribute_id,
			"components": component_data,
			"flags": spec.flags.duplicate(),
			"capture_policy": spec.capture_policy,
		},
		spec.source_entity_id,
		[spec.target_entity_id],
		"",
		0,
		spec.cause_chain
	)
	return _pipeline.dispatch(request, _state.logical_tick)


func resolve_hit(
	source_entity_id: String,
	target_entity_id: String,
	outcome: String = "success",
	reason: String = ""
) -> RefCounted:
	var result := HitResultScript.new()
	result.source_entity_id = source_entity_id
	result.target_entity_id = target_entity_id
	result.outcome = outcome
	result.reason = reason
	return result


func resolve_hit_event(
	source_entity_id: String,
	target_entity_id: String,
	outcome: String = "success",
	reason: String = "",
	logical_tick: int = 0
) -> RefCounted:
	return _hit_module.resolve(source_entity_id, target_entity_id, outcome, reason, logical_tick)
