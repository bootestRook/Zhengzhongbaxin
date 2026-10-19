class_name DefenseCastGraph
extends RefCounted

const Plan = preload("res://src/runtime/ability/ability_execution_plan.gd")
const Run = preload("res://src/runtime/ability/ability_run.gd")
const Registry = preload("res://src/runtime/ability/ability_action_registry.gd")
const Executor = preload("res://src/runtime/action_executor.gd")
const Result = preload("res://src/runtime/action_result.gd")
var plan
var registry
var executor
var serial: int = 0

class CastContext extends RefCounted:
	var world
	var owner: Dictionary
	var target: Dictionary
	var skill: Dictionary
	var origin: Vector2
	var delay: int

class LaunchAction extends RefCounted:
	func action_id() -> String:
		return "defense.cast"
	func atomicity() -> String:
		return "stepwise"
	func validate(context) -> String:
		return "invalid_cast" if context.owner.is_empty() or (context.owner.dead and not context.skill.get("death_cast", false)) or not context.skill.has("type") else ""
	func execute(context):
		context.world.projectiles.launch(context.owner, context.target, context.skill, context.origin, context.delay)
		return Result.success([{"type": "skill_launched", "skill": context.skill.__id__, "owner": context.owner.id}])

class Resolver extends RefCounted:
	func build_action() -> RefCounted:
		return LaunchAction.new()

func _init() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/generated/ability_plans.json"))
	plan = Plan.from_dictionary(data.plans["defense.cast"])
	registry = Registry.new()
	registry.register_action("defense.cast", Resolver.new())
	executor = Executor.new(64)

func launch(world, owner: Dictionary, target: Dictionary, skill: Dictionary, origin: Vector2, delay: int) -> bool:
	var context = CastContext.new()
	context.world = world
	context.owner = owner
	context.target = target
	context.skill = skill
	context.origin = origin
	context.delay = delay
	serial += 1
	var run = Run.new(plan, registry, executor, "cast.%d" % serial)
	if not run.validate(context).is_empty():
		return false
	var result = run.execute(context)
	context.world = null
	return result.accepted
