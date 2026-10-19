class_name CoreConditionRegistry
extends RefCounted

const ResultScript = preload("res://src/runtime/core/core_condition_result.gd")

var _evaluators: Dictionary = {}


func register(condition_id: String, evaluator: RefCounted) -> String:
	if condition_id.is_empty():
		return "condition_id_empty"
	if evaluator == null or not evaluator.has_method("evaluate"):
		return "invalid_condition_evaluator"
	if _evaluators.has(condition_id):
		return "duplicate_condition_id"
	_evaluators[condition_id] = evaluator
	return ""


func evaluate(condition_id: String, context: RefCounted, parameters: Dictionary = {}) -> RefCounted:
	var evaluator: RefCounted = _evaluators.get(condition_id)
	if evaluator == null:
		return ResultScript.fail_result("unknown_condition")
	var result = evaluator.evaluate(context, parameters.duplicate(true))
	if result is ResultScript:
		return result
	return ResultScript.fail_result("invalid_condition_result")
