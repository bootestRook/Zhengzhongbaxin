class_name CoreTargetResolverRegistry
extends RefCounted

const ResultScript = preload("res://src/runtime/core/core_target_result.gd")
const QueryDefinitionScript = preload("res://src/runtime/core/core_target_query_definition.gd")

var _resolvers: Dictionary = {}


func register(target_type: String, resolver: RefCounted) -> String:
	if target_type.is_empty():
		return "target_type_empty"
	if resolver == null or not resolver.has_method("resolve"):
		return "invalid_target_resolver"
	if _resolvers.has(target_type):
		return "duplicate_target_type"
	_resolvers[target_type] = resolver
	return ""


func has(target_type: String) -> bool:
	return _resolvers.has(target_type)


func resolve(target_type: String, context: RefCounted, parameters: Dictionary = {}) -> RefCounted:
	var resolver: RefCounted = _resolvers.get(target_type)
	if resolver == null:
		return ResultScript.rejected("unknown_target_type")
	var result = resolver.resolve(context, parameters.duplicate(true))
	if result is ResultScript:
		return result
	return ResultScript.rejected("invalid_target_result")


func register_builtins() -> String:
	var builtins := {
		"self": Callable(self, "_resolve_self"),
		"explicit": Callable(self, "_resolve_explicit"),
		"source": Callable(self, "_resolve_source"),
		"targets": Callable(self, "_resolve_targets"),
		"query": Callable(self, "_resolve_query"),
	}
	for target_type: String in builtins:
		var error := register(target_type, _CallableTargetResolver.new(builtins[target_type]))
		if not error.is_empty():
			return error
	return ""


func _resolve_self(context: RefCounted, _parameters: Dictionary) -> RefCounted:
	var entity_id := String(context.source_entity_id)
	return ResultScript.success([entity_id]) if not entity_id.is_empty() else ResultScript.rejected("source_entity_missing")


func _resolve_explicit(_context: RefCounted, parameters: Dictionary) -> RefCounted:
	var ids: Array[String] = []
	for entity_id: String in parameters.get("entity_ids", []):
		if not entity_id.is_empty() and not ids.has(entity_id):
			ids.append(entity_id)
	ids.sort()
	return ResultScript.success(ids)


func _resolve_source(context: RefCounted, _parameters: Dictionary) -> RefCounted:
	var entity_id := String(context.source_entity_id)
	return ResultScript.success([entity_id]) if not entity_id.is_empty() else ResultScript.rejected("source_entity_missing")


func _resolve_targets(context: RefCounted, _parameters: Dictionary) -> RefCounted:
	var ids: Array[String] = []
	for entity_id: String in context.target_entity_ids:
		if not ids.has(entity_id):
			ids.append(entity_id)
	return ResultScript.success(ids)


func _resolve_query(context: RefCounted, parameters: Dictionary) -> RefCounted:
	if context == null or context.state == null or not context.state.has_method("entities_in_sequence_order"):
		return ResultScript.rejected("target_query_state_missing")
	var configured_definition: Variant = parameters.get("definition", null)
	if configured_definition != null:
		if not (configured_definition is QueryDefinitionScript):
			return ResultScript.rejected("target_query_definition_invalid")
		var definition_error: String = configured_definition.validate()
		if not definition_error.is_empty():
			return ResultScript.rejected(definition_error)
		parameters = configured_definition.snapshot()
	var candidates: Array[RefCounted] = context.state.entities_in_sequence_order()
	var relationship := String(parameters.get("relationship", "any"))
	var lifecycle := String(parameters.get("lifecycle", "active"))
	var include_query_value: Variant = parameters.get("include_tag_query", {})
	var exclude_query_value: Variant = parameters.get("exclude_tag_query", {})
	if not (include_query_value is Dictionary) or not (exclude_query_value is Dictionary):
		return ResultScript.rejected("target_query_tag_filter_invalid")
	var include_query: Dictionary = include_query_value
	var exclude_query: Dictionary = exclude_query_value
	var result: Array[String] = []
	for entity: RefCounted in candidates:
		if relationship == "self" and entity.entity_id != context.source_entity_id:
			continue
		if relationship == "other" and entity.entity_id == context.source_entity_id:
			continue
		if lifecycle != "any" and entity.lifecycle != lifecycle:
			continue
		if not include_query.is_empty() and not entity.tags.matches_query(include_query):
			continue
		if not exclude_query.is_empty() and entity.tags.matches_query(exclude_query):
			continue
		result.append(entity.entity_id)
	if String(parameters.get("order", "sequence")) == "entity_id":
		result.sort()
	var limit := int(parameters.get("limit", -1))
	if limit > 0 and result.size() > limit:
		result.resize(limit)
	return ResultScript.success(result, {"query": parameters.duplicate(true), "candidate_count": candidates.size()})


class _CallableTargetResolver extends RefCounted:
	var _callback: Callable

	func _init(callback: Callable) -> void:
		_callback = callback

	func resolve(context: RefCounted, parameters: Dictionary) -> RefCounted:
		return _callback.call(context, parameters)
