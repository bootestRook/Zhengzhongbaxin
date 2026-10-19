class_name CoreCueRouter
extends RefCounted

var _resolvers: Dictionary = {}


func register(cue_key: String, resolver: RefCounted) -> String:
	if cue_key.is_empty():
		return "cue_key_empty"
	if resolver == null or not resolver.has_method("resolve"):
		return "invalid_cue_resolver"
	if _resolvers.has(cue_key):
		return "duplicate_cue_key"
	_resolvers[cue_key] = resolver
	return ""


func route(events: Array[RefCounted]) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	for event: RefCounted in events:
		var cue_key: String = String(event.payload.get("cue_key", ""))
		if cue_key.is_empty() or not _resolvers.has(cue_key):
			continue
		var command = _resolvers[cue_key].resolve(event)
		if typeof(command) == TYPE_DICTIONARY:
			commands.append(command)
	return commands
