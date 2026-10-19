@tool
class_name AbilityEditorPlaceholderAction
extends RefCounted

const ActionResultScript = preload("res://src/runtime/action_result.gd")


func action_id() -> String:
	return "editor.placeholder"


func atomicity() -> String:
	return "atomic"


func validate(_context: RefCounted) -> String:
	return ""


func execute(_context: RefCounted):
	return ActionResultScript.success([{"type": "editor.placeholder_executed"}])
