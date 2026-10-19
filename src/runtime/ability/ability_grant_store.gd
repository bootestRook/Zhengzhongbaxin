class_name AbilityGrantStore
extends RefCounted

var _grants: Dictionary = {}
var _next_sequence: int = 1


func grant(ability_id: String, source_id: String = "") -> String:
	if ability_id.is_empty():
		return "ability_id_empty"
	var handle := "%s#%d" % [ability_id, _next_sequence]
	_grants[handle] = {"ability_id": ability_id, "source_id": source_id, "sequence": _next_sequence}
	_next_sequence += 1
	return handle


func revoke(handle: String) -> String:
	if not _grants.has(handle):
		return "unknown_ability_grant"
	_grants.erase(handle)
	return ""


func ability_id(handle: String) -> String:
	return String(_grants.get(handle, {}).get("ability_id", ""))


func has(handle: String) -> bool:
	return _grants.has(handle)


func handles() -> Array[String]:
	var result: Array[String] = []
	for handle: String in _grants.keys():
		result.append(handle)
	result.sort()
	return result


func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for handle: String in handles():
		var entry: Dictionary = _grants[handle].duplicate(true)
		entry["handle"] = handle
		result.append(entry)
	return result


func snapshot() -> Dictionary:
	return {"next_sequence": _next_sequence, "grants": _grants.duplicate(true)}


func restore(snapshot: Dictionary) -> String:
	var grants: Variant = snapshot.get("grants", null)
	if typeof(grants) != TYPE_DICTIONARY:
		return "ability_grant_snapshot_invalid"
	_grants = grants.duplicate(true)
	_next_sequence = int(snapshot.get("next_sequence", 1))
	return ""
