class_name CoreTargetQueryDefinition
extends RefCounted

var query_id: String = ""
var relationship: String = "any"
var lifecycle: String = "active"
var include_tag_query: Dictionary = {}
var exclude_tag_query: Dictionary = {}
var order: String = "sequence"
var limit: int = -1


func _init(configured_query_id: String = "") -> void:
	query_id = configured_query_id


func validate() -> String:
	if query_id.is_empty():
		return "target_query_id_empty"
	if not ["any", "self", "other"].has(relationship):
		return "target_query_relationship_invalid"
	if not ["any", "active", "defeated", "removed"].has(lifecycle):
		return "target_query_lifecycle_invalid"
	if not ["sequence", "entity_id"].has(order):
		return "target_query_order_invalid"
	if limit == 0 or limit < -1:
		return "target_query_limit_invalid"
	return ""


func snapshot() -> Dictionary:
	return {
		"query_id": query_id,
		"relationship": relationship,
		"lifecycle": lifecycle,
		"include_tag_query": include_tag_query.duplicate(true),
		"exclude_tag_query": exclude_tag_query.duplicate(true),
		"order": order,
		"limit": limit,
	}
