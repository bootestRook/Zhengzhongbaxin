class_name GameplayModuleCatalog
extends RefCounted

const TargetResolverScript = preload("res://src/runtime/core/core_target_resolver_registry.gd")
const TargetActionScript = preload("res://src/runtime/ability/ability_target_action_resolver.gd")
const DamageScript = preload("res://src/runtime/modules/damage/damage_module.gd")
const BuffScript = preload("res://src/runtime/modules/buff/buff_module.gd")
const ProjectileScript = preload("res://src/runtime/modules/projectile/projectile_module.gd")
const MovementScript = preload("res://src/runtime/modules/movement/movement_module.gd")
const SummonScript = preload("res://src/runtime/modules/summon/summon_module.gd")
const AreaScript = preload("res://src/runtime/modules/area/area_module.gd")


static func register_default_actions(
	state: RefCounted,
	pipeline: RefCounted,
	action_registry: RefCounted,
	target_registry: RefCounted = null
) -> Dictionary:
	if state == null or pipeline == null or action_registry == null:
		return {"error_code": "module_catalog_dependency_missing"}
	var targets: RefCounted = target_registry if target_registry != null else TargetResolverScript.new()
	if not targets.has("self"):
		var target_error: String = targets.register_builtins()
		if not target_error.is_empty():
			return {"error_code": target_error}
	var target_action_error: String = action_registry.register_action("module.target.select", TargetActionScript.new())
	if not target_action_error.is_empty() and not action_registry.has_action("module.target.select"):
		return {"error_code": target_action_error}
	var damage := DamageScript.new(state, pipeline)
	var damage_error := damage.register()
	if damage_error.is_empty():
		damage_error = damage.register_actions(action_registry)
	if not damage_error.is_empty():
		return {"error_code": damage_error}
	var buff := BuffScript.new(state)
	var buff_error := buff.register_actions(action_registry)
	if not buff_error.is_empty():
		return {"error_code": buff_error}
	var projectile := ProjectileScript.new()
	var projectile_error := projectile.register_actions(action_registry)
	if not projectile_error.is_empty():
		return {"error_code": projectile_error}
	var movement := MovementScript.new()
	var movement_error := movement.register_actions(action_registry)
	if not movement_error.is_empty():
		return {"error_code": movement_error}
	var summon := SummonScript.new(state)
	var summon_error := summon.register_actions(action_registry)
	if not summon_error.is_empty():
		return {"error_code": summon_error}
	var area := AreaScript.new()
	var area_error := area.register_actions(action_registry)
	if not area_error.is_empty():
		return {"error_code": area_error}
	return {
		"error_code": "",
		"target_registry": targets,
		"damage": damage,
		"buff": buff,
		"projectile": projectile,
		"movement": movement,
		"summon": summon,
		"area": area,
	}
