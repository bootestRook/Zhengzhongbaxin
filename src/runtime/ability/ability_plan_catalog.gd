class_name AbilityPlanCatalog
extends RefCounted

const DEFAULT_CATALOG_PATH := "res://data/generated/ability_plans.json"
const PlanScript = preload("res://src/runtime/ability/ability_execution_plan.gd")

var schema_version: int = 0
var _plans: Dictionary = {}


func load_default() -> String:
	if not FileAccess.file_exists(DEFAULT_CATALOG_PATH):
		return "ability plan catalog is missing; run the graph generation step"
	var file := FileAccess.open(DEFAULT_CATALOG_PATH, FileAccess.READ)
	if file == null:
		return "cannot open ability plan catalog"
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return "ability plan catalog root must be an object"
	schema_version = int(parsed.get("schema_version", 0))
	if schema_version <= 0 or typeof(parsed.get("plans", {})) != TYPE_DICTIONARY:
		return "ability plan catalog has an invalid shape"
	_plans.clear()
	for graph_id: String in parsed.plans:
		_plans[graph_id] = PlanScript.from_dictionary(parsed.plans[graph_id])
	return ""


func plan(graph_id: String) -> RefCounted:
	return _plans.get(graph_id)


func has_plan(graph_id: String) -> bool:
	return _plans.has(graph_id)


func graph_ids() -> Array[String]:
	var result: Array[String] = []
	for graph_id: String in _plans:
		result.append(graph_id)
	result.sort()
	return result
