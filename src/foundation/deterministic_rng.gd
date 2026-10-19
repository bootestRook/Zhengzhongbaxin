class_name DeterministicRng
extends RefCounted

const _MASK := 0x7fffffff
const _MULTIPLIER := 1103515245
const _INCREMENT := 12345

var _state: int = 1
var _counter: int = 0


func _init(seed: int = 1) -> void:
	_state = seed & _MASK
	if _state == 0:
		_state = 1


func next_int(max_exclusive: int) -> int:
	assert(max_exclusive > 0, "max_exclusive must be positive")
	_state = (_MULTIPLIER * _state + _INCREMENT) & _MASK
	_counter += 1
	return _state % max_exclusive


func shuffle(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := next_int(index + 1)
		var temporary: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary


func choose_weighted(rows: Array, weight_field: String = "weight") -> Dictionary:
	var total := 0
	for row: Dictionary in rows:
		total += maxi(0, int(row.get(weight_field, 0)))
	if total <= 0:
		return {}
	var roll := next_int(total)
	for row: Dictionary in rows:
		roll -= maxi(0, int(row.get(weight_field, 0)))
		if roll < 0:
			return row
	return rows.back()


func snapshot() -> Dictionary:
	return {"state": _state, "counter": _counter}


func restore(data: Dictionary) -> String:
	var restored_state := int(data.get("state", 0)) & _MASK
	var restored_counter := int(data.get("counter", -1))
	if restored_state == 0 or restored_counter < 0:
		return "invalid RNG snapshot"
	_state = restored_state
	_counter = restored_counter
	return ""


func get_counter() -> int:
	return _counter
