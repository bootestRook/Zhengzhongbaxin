class_name CoreTargetResult
extends RefCounted

var accepted: bool = false
var entity_ids: Array[String] = []
var observation: Dictionary = {}
var error_code: String = ""


static func success(ids: Array[String], target_observation: Dictionary = {}) -> CoreTargetResult:
	var result := CoreTargetResult.new()
	result.accepted = true
	result.entity_ids = ids.duplicate()
	result.observation = target_observation.duplicate(true)
	return result


static func rejected(code: String) -> CoreTargetResult:
	var result := CoreTargetResult.new()
	result.error_code = code
	return result
