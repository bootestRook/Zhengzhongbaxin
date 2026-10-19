class_name AreaQueryActionResolver
extends RefCounted

const ActionResultScript = preload("res://src/runtime/action_result.gd")

var _module: RefCounted


func _init(area_module: RefCounted) -> void:
	_module = area_module


func build_action() -> RefCounted:
	return AreaQueryAction.new(_module)


class AreaQueryAction extends RefCounted:
	var _module: RefCounted
	var _parameters: Dictionary = {}

	func _init(area_module: RefCounted) -> void:
		_module = area_module

	func configure(parameters: Dictionary) -> void:
		_parameters = parameters.duplicate(true)

	func action_id() -> String:
		return "module.area.query"

	func atomicity() -> String:
		return "atomic"

	func validate(context: RefCounted) -> String:
		if _module == null or context == null or not context.has_method("set_targets"):
			return "area_dependency_missing"
		if String(_parameters.get("area_id", "")).is_empty():
			return "area_id_empty"
		return ""

	func execute(context: RefCounted):
		var ids: Array[String] = _module.members(String(_parameters.area_id))
		context.set_targets(ids)
		context.set_value("targets", ids)
		return ActionResultScript.success([{"type": "area.queried", "area_id": String(_parameters.area_id), "entity_ids": ids}])
