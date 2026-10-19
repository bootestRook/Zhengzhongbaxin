class_name ActionResult
extends RefCounted

var accepted: bool
var error_code: String
var events: Array


func _init(is_accepted: bool = false, code: String = "", emitted_events: Array = []) -> void:
	accepted = is_accepted
	error_code = code
	events = emitted_events


static func success(emitted_events: Array = []):
	return ActionResult.new(true, "", emitted_events)


static func rejected(code: String):
	return ActionResult.new(false, code, [])
