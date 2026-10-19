class_name CoreEventTraceComparison
extends RefCounted


static func compare(left: Array[Dictionary], right: Array[Dictionary]) -> Dictionary:
	if left.size() != right.size():
		return _mismatch(-1, "entry_count", left.size(), right.size())
	for index in range(left.size()):
		var left_entry: Dictionary = left[index]
		var right_entry: Dictionary = right[index]
		for key: String in [
			"event_type",
			"request_payload",
			"source_entity_id",
			"target_entity_ids",
			"logical_tick",
			"cause_chain",
			"facts",
			"handler_trace",
			"error_code",
		]:
			if left_entry.get(key, null) != right_entry.get(key, null):
				return _mismatch(index, key, left_entry.get(key, null), right_entry.get(key, null))
	return {"accepted": true, "index": -1, "field": "", "left": null, "right": null}


static func compare_snapshots(left: Dictionary, right: Dictionary) -> Dictionary:
	if typeof(left.get("entries", null)) != TYPE_ARRAY or typeof(right.get("entries", null)) != TYPE_ARRAY:
		return _mismatch(-1, "snapshot", left, right)
	return compare(left.entries, right.entries)


static func _mismatch(index: int, field: String, left: Variant, right: Variant) -> Dictionary:
	return {"accepted": false, "index": index, "field": field, "left": left, "right": right}
