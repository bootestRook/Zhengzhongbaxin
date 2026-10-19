class_name MovementActionResolver
extends RefCounted

const ActionResultScript = preload("res://src/runtime/action_result.gd")

var _module: RefCounted


func _init(movement_module: RefCounted) -> void:
	_module = movement_module


func build_action() -> RefCounted:
	return MoveAction.new(_module)


class MoveAction extends RefCounted:
	var _module: RefCounted
	var _parameters: Dictionary = {}

	func _init(movement_module: RefCounted) -> void:
		_module = movement_module

	func configure(parameters: Dictionary) -> void:
		_parameters = parameters.duplicate(true)

	func action_id() -> String:
		return "module.movement.move"

	func atomicity() -> String:
		return "atomic"

	func validate(context: RefCounted) -> String:
		if _module == null or context == null:
			return "movement_dependency_missing"
		if String(_parameters.get("entity_id", context.source_entity_id)).is_empty():
			return "movement_entity_empty"
		return ""

	func execute(context: RefCounted):
		var vector := _vector(_parameters.get("displacement", [0.0, 0.0, 0.0]))
		var event = _module.move(
			String(_parameters.get("entity_id", context.source_entity_id)),
			vector,
			String(_parameters.get("mode", "add")),
			int(context.logical_tick)
		)
		if event == null:
			return ActionResultScript.rejected("movement_rejected")
		return ActionResultScript.success([event])

	func _vector(raw: Variant) -> Vector3:
		if raw is Vector3:
			return raw
		if raw is Array and raw.size() >= 3:
			return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
		return Vector3.ZERO
