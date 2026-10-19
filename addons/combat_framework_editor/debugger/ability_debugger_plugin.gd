@tool
class_name AbilityDebuggerPlugin
extends EditorDebuggerPlugin

signal snapshot_received(snapshot: Dictionary)


func _has_capture(capture: String) -> bool:
	return capture == "combat_ability"


func _capture(message: String, data: Array, _session_id: int) -> bool:
	if message != "combat_ability/snapshot" or data.is_empty():
		return false
	if typeof(data[0]) != TYPE_DICTIONARY:
		return false
	snapshot_received.emit(data[0])
	return true
