class_name AbilityTargetActionResolver
extends RefCounted

const ActionResultScript = preload("res://src/runtime/action_result.gd")


func build_action() -> RefCounted:
	return SelectTargetAction.new()


class SelectTargetAction extends RefCounted:
	var _parameters: Dictionary = {}

	func configure(parameters: Dictionary) -> void:
		_parameters = parameters.duplicate(true)

	func action_id() -> String:
		return "module.target.select"

	func atomicity() -> String:
		return "atomic"

	func validate(context: RefCounted) -> String:
		if context == null or not context.has_method("resolve_target"):
			return "target_execution_context_missing"
		if String(_parameters.get("target_type", "targets")).is_empty():
			return "target_type_empty"
		return ""

	func execute(context: RefCounted):
		var result = context.resolve_target(
			String(_parameters.get("target_type", "targets")),
			_parameters
		)
		if result == null or not result.accepted:
			return ActionResultScript.rejected(result.error_code if result != null else "target_result_missing")
		context.set_targets(result.entity_ids)
		context.set_value("targets", result.entity_ids)
		return ActionResultScript.success(
			[
				{
					"type": "target.selected",
					"entity_ids": result.entity_ids.duplicate(),
				}
			]
		)
