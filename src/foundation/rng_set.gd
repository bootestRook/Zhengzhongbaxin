class_name RngSet
extends RefCounted

const DeterministicRngScript = preload("res://src/foundation/deterministic_rng.gd")
const _MASK := 0x7fffffff

var _base_seed: int = 1
var _streams: Dictionary = {}


func _init(base_seed: int = 1) -> void:
	_base_seed = base_seed & _MASK
	if _base_seed == 0:
		_base_seed = 1


func stream(stream_name: String):
	assert(not stream_name.is_empty(), "stream name must not be empty")
	if not _streams.has(stream_name):
		_streams[stream_name] = DeterministicRngScript.new(_derive_seed(stream_name))
	return _streams[stream_name]


func snapshot() -> Dictionary:
	var names := _streams.keys()
	names.sort()
	var stream_data := {}
	for stream_name: String in names:
		stream_data[stream_name] = _streams[stream_name].snapshot()
	return {"base_seed": _base_seed, "streams": stream_data}


func restore(data: Dictionary) -> String:
	var base_seed := int(data.get("base_seed", 0)) & _MASK
	var stream_data: Variant = data.get("streams", {})
	if base_seed == 0 or typeof(stream_data) != TYPE_DICTIONARY:
		return "invalid RNG set snapshot"
	_base_seed = base_seed
	_streams.clear()
	for stream_name: String in stream_data:
		var rng = DeterministicRngScript.new(_derive_seed(stream_name))
		var error: String = rng.restore(stream_data[stream_name])
		if not error.is_empty():
			return "%s: %s" % [stream_name, error]
		_streams[stream_name] = rng
	return ""


func _derive_seed(stream_name: String) -> int:
	var value := (2166136261 ^ _base_seed) & _MASK
	for byte: int in stream_name.to_utf8_buffer():
		value = ((value ^ byte) * 16777619) & _MASK
	return value if value != 0 else 1
