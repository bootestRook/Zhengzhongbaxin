class_name ProjectileActionResolver
extends RefCounted

const ActionResultScript = preload("res://src/runtime/action_result.gd")

var _module: RefCounted


func _init(projectile_module: RefCounted) -> void:
	_module = projectile_module


func build_action() -> RefCounted:
	return SpawnProjectileAction.new(_module)


class SpawnProjectileAction extends RefCounted:
	var _module: RefCounted
	var _parameters: Dictionary = {}

	func _init(projectile_module: RefCounted) -> void:
		_module = projectile_module

	func configure(parameters: Dictionary) -> void:
		_parameters = parameters.duplicate(true)

	func action_id() -> String:
		return "module.projectile.spawn"

	func atomicity() -> String:
		return "atomic"

	func validate(context: RefCounted) -> String:
		if _module == null or context == null:
			return "projectile_dependency_missing"
		if String(_parameters.get("definition_id", "")).is_empty():
			return "projectile_definition_empty"
		if not _module.has_definition(String(_parameters.get("definition_id", ""))):
			return "projectile_definition_unknown"
		if context.target_entity_ids.is_empty():
			return "projectile_target_empty"
		return ""

	func execute(context: RefCounted):
		var target_ids: Array[String] = context.target_entity_ids.duplicate()
		var configured_targets: Variant = _parameters.get("target_entity_ids", null)
		if configured_targets is Array and not configured_targets.is_empty():
			target_ids.assign(configured_targets)
		var events: Array = []
		for target_id: String in target_ids:
			var instance = _module.spawn(
				String(context.source_entity_id), target_id,
				String(_parameters.definition_id), int(context.logical_tick)
			)
			if instance == null:
				return ActionResultScript.rejected("projectile_spawn_failed")
			events.append({"type": "projectile.spawned", "projectile_id": instance.projectile_id, "target_entity_id": target_id})
		return ActionResultScript.success(events)
