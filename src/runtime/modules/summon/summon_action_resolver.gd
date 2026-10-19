class_name SummonActionResolver
extends RefCounted

const ActionResultScript = preload("res://src/runtime/action_result.gd")

var _module: RefCounted


func _init(summon_module: RefCounted) -> void:
	_module = summon_module


func build_action() -> RefCounted:
	return SummonAction.new(_module)


class SummonAction extends RefCounted:
	var _module: RefCounted
	var _parameters: Dictionary = {}

	func _init(summon_module: RefCounted) -> void:
		_module = summon_module

	func configure(parameters: Dictionary) -> void:
		_parameters = parameters.duplicate(true)

	func action_id() -> String:
		return "module.summon.create"

	func atomicity() -> String:
		return "atomic"

	func validate(context: RefCounted) -> String:
		if _module == null or context == null:
			return "summon_dependency_missing"
		if String(_parameters.get("definition_id", "")).is_empty():
			return "summon_definition_empty"
		return ""

	func execute(context: RefCounted):
		var event = _module.summon(
			String(context.source_entity_id),
			String(_parameters.definition_id),
			int(context.logical_tick),
			int(_parameters.get("lifetime_ticks", -1))
		)
		if event == null:
			return ActionResultScript.rejected("summon_failed")
		return ActionResultScript.success([event])
