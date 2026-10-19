class_name IncrementAction
extends RefCounted

const ChangeValueCommandScript = preload("res://src/features/sample_interaction/domain/commands/change_value_command.gd")

var _intent


func _init(intent: RefCounted) -> void:
	_intent = intent


func action_id() -> String:
	return "sample.increment"


func atomicity() -> String:
	return "atomic"


func validate(context: RefCounted) -> String:
	if _intent.kind != "sample.increment":
		return "unsupported_intent"
	if _intent.target_instance_id != context.state.instance_id:
		return "target_not_found"
	if context.state.completed:
		return "sample_already_complete"
	return ""


func execute(context: RefCounted):
	var step := maxi(1, int(round(context.data.tuning_value(context.state.definition_id, "step", 1.0))))
	var bonus_chance := clampi(int(round(context.data.tuning_value(context.state.definition_id, "bonus_chance", 0.0))), 0, 100)
	var bonus: bool = context.rng.stream("sample_outcome").next_int(100) < bonus_chance
	var result = ChangeValueCommandScript.new().execute(context, step + (1 if bonus else 0))
	if result.accepted and bonus:
		result.events.push_front({"type": "sample.bonus_applied", "delta": 1})
	return result
