class_name BuffActionResolver
extends RefCounted

const ActionResultScript = preload("res://src/runtime/action_result.gd")


func build_action() -> RefCounted:
	return ApplyEffectAction.new()


class ApplyEffectAction extends RefCounted:
	var _parameters: Dictionary = {}

	func configure(parameters: Dictionary) -> void:
		_parameters = parameters.duplicate(true)

	func action_id() -> String:
		return "module.effect.apply"

	func atomicity() -> String:
		return "atomic"

	func validate(context: RefCounted) -> String:
		if context == null or not context.has_method("set_value"):
			return "effect_execution_context_missing"
		if String(_parameters.get("effect_id", "")).is_empty():
			return "effect_id_empty"
		if context.state == null:
			return "effect_state_missing"
		if _targets(context).is_empty():
			return "effect_targets_empty"
		return ""

	func execute(context: RefCounted):
		var events: Array = []
		for target_id: String in _targets(context):
			var target: RefCounted = context.state.entity(target_id)
			if target == null:
				return ActionResultScript.rejected("effect_target_missing")
			var instance: RefCounted = target.effects.apply(
				String(_parameters.effect_id),
				String(context.source_entity_id),
				int(context.logical_tick),
				target_id
			)
			if instance == null:
				return ActionResultScript.rejected("unknown_effect")
			events.append(
				{
					"type": "effect.applied",
					"effect_id": instance.effect_id,
					"instance_id": instance.instance_id,
					"target_entity_id": target_id,
				}
			)
		return ActionResultScript.success(events)

	func _targets(context: RefCounted) -> Array[String]:
		var configured: Variant = _parameters.get("target_entity_ids", null)
		if configured is Array and not configured.is_empty():
			var result: Array[String] = []
			result.assign(configured)
			return result
		return context.target_entity_ids.duplicate()
