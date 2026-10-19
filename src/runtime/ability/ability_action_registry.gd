class_name AbilityActionRegistry
extends RefCounted

var _resolvers: Dictionary = {} # Explicit registration only; no runtime class discovery.


func register_action(action_id: String, resolver: RefCounted) -> String:
	if action_id.is_empty():
		return "action_id_empty"
	if resolver == null or not resolver.has_method("build_action"):
		return "invalid_action_resolver"
	if _resolvers.has(action_id):
		return "duplicate_action_id"
	_resolvers[action_id] = resolver
	return ""


func has_action(action_id: String) -> bool:
	return _resolvers.has(action_id)


func build_action(action_id: String) -> RefCounted:
	var resolver: RefCounted = _resolvers.get(action_id)
	if resolver == null:
		return null
	var action = resolver.build_action()
	return action if action is RefCounted else null
