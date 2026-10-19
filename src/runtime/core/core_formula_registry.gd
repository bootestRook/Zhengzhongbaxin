class_name CoreFormulaRegistry
extends RefCounted

const ResultScript = preload("res://src/runtime/core/core_formula_result.gd")

var _evaluators: Dictionary = {}


func register(formula_id: String, evaluator: RefCounted) -> String:
	if formula_id.is_empty():
		return "formula_id_empty"
	if evaluator == null or not evaluator.has_method("evaluate"):
		return "invalid_formula_evaluator"
	if _evaluators.has(formula_id):
		return "duplicate_formula_id"
	_evaluators[formula_id] = evaluator
	return ""


func evaluate(formula_id: String, context: RefCounted, parameters: Dictionary = {}) -> RefCounted:
	var evaluator: RefCounted = _evaluators.get(formula_id)
	if evaluator == null:
		return ResultScript.rejected("unknown_formula")
	var result = evaluator.evaluate(context, parameters.duplicate(true))
	if result is ResultScript:
		return result
	return ResultScript.rejected("invalid_formula_result")
