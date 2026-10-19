class_name AbilityCooldownStore
extends RefCounted

var _ready_ticks: Dictionary = {}


func is_ready(handle: String, current_tick: int) -> bool:
	return current_tick >= int(_ready_ticks.get(handle, 0))


func start(handle: String, current_tick: int, duration_ticks: int) -> String:
	if handle.is_empty() or duration_ticks < 0:
		return "cooldown_arguments_invalid"
	_ready_ticks[handle] = current_tick + duration_ticks
	return ""


func ready_tick(handle: String) -> int:
	return int(_ready_ticks.get(handle, 0))


func snapshot() -> Dictionary:
	return _ready_ticks.duplicate(true)


func restore(snapshot: Dictionary) -> String:
	_ready_ticks = snapshot.duplicate(true)
	return ""
