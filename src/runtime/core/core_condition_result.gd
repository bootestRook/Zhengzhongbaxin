class_name CoreConditionResult
extends RefCounted

var passed: bool = false
var reason_code: String = ""


static func pass_result() -> CoreConditionResult:
	var result := CoreConditionResult.new()
	result.passed = true
	return result


static func fail_result(code: String) -> CoreConditionResult:
	var result := CoreConditionResult.new()
	result.reason_code = code
	return result
