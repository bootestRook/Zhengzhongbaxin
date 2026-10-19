class_name CoreFormulaResult
extends RefCounted

var accepted: bool = false
var value: float = 0.0
var error_code: String = ""


static func success(formula_value: float) -> CoreFormulaResult:
	var result := CoreFormulaResult.new()
	result.accepted = true
	result.value = formula_value
	return result


static func rejected(code: String) -> CoreFormulaResult:
	var result := CoreFormulaResult.new()
	result.error_code = code
	return result
