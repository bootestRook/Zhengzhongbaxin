class_name CoreTagStore
extends RefCounted

var _grants: Dictionary = {}
var _next_sequence: int = 1


func grant(tag_id: String, source_id: String = "") -> String:
	if tag_id.is_empty():
		return "tag_id_empty"
	var handle := "%s#%d" % [tag_id, _next_sequence]
	_next_sequence += 1
	_grants[handle] = {"tag_id": tag_id, "source_id": source_id, "sequence": _next_sequence - 1}
	return handle


func revoke(handle: String) -> String:
	if not _grants.has(handle):
		return "unknown_tag_grant"
	_grants.erase(handle)
	return ""


func has_tag(tag_id: String) -> bool:
	for grant: Dictionary in _grants.values():
		if grant.tag_id == tag_id:
			return true
	return false


func matches(tag_query: String) -> bool:
	if tag_query.is_empty():
		return false
	for grant: Dictionary in _grants.values():
		var granted_id := String(grant.tag_id)
		if granted_id == tag_query or granted_id.begins_with(tag_query + "."):
			return true
	return false


func matches_query(query: Dictionary) -> bool:
	if query.has("all"):
		for child: Variant in query.get("all", []):
			if child is String:
				if not matches(String(child)):
					return false
			elif child is Dictionary and not matches_query(child):
				return false
	if query.has("any"):
		var any_match := false
		for child: Variant in query.get("any", []):
			if child is String and matches(String(child)):
				any_match = true
			elif child is Dictionary and matches_query(child):
				any_match = true
		if not any_match:
			return false
	if query.has("none"):
		for child: Variant in query.get("none", []):
			if child is String and matches(String(child)):
				return false
			elif child is Dictionary and matches_query(child):
				return false
	return true


func handles_for_tag(tag_id: String) -> Array[String]:
	var handles: Array[String] = []
	for handle: String in _grants:
		if _grants[handle].tag_id == tag_id:
			handles.append(handle)
	handles.sort()
	return handles


func snapshot() -> Dictionary:
	return {"next_sequence": _next_sequence, "grants": _grants.duplicate(true)}


func restore(snapshot: Dictionary) -> String:
	var grants: Variant = snapshot.get("grants", null)
	if typeof(grants) != TYPE_DICTIONARY:
		return "tag_snapshot_invalid"
	_next_sequence = int(snapshot.get("next_sequence", 1))
	_grants = grants.duplicate(true)
	return ""
