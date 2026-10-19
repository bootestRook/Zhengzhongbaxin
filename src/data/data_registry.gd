class_name DataRegistry
extends RefCounted

const DEFAULT_CATALOG_PATH := "res://data/generated/data_catalog.json"

var schema_version: int = 0
var _tables: Dictionary = {}
var _by_id: Dictionary = {}


func load_default() -> String:
	if not FileAccess.file_exists(DEFAULT_CATALOG_PATH):
		return "generated data is missing; run: python tools/project.py data"
	var file := FileAccess.open(DEFAULT_CATALOG_PATH, FileAccess.READ)
	if file == null:
		return "cannot open generated data catalog"
	return load_json(file.get_as_text())


func load_json(text: String) -> String:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return "data catalog root must be an object"
	var parsed_tables: Variant = parsed.get("tables", {})
	if typeof(parsed_tables) != TYPE_DICTIONARY:
		return "data catalog must contain tables"
	schema_version = int(parsed.get("schema_version", 0))
	if schema_version <= 0:
		return "data catalog schema_version must be positive"
	_tables = parsed_tables
	_by_id.clear()
	for table_name: String in _tables:
		var index := {}
		for row: Dictionary in _tables[table_name]:
			if row.has("id"):
				index[String(row.id)] = row
			elif row.has("key"):
				index[String(row.key)] = row
		_by_id[table_name] = index
	return ""


func row(table_name: String, row_id: String) -> Dictionary:
	var found: Dictionary = _by_id.get(table_name, {}).get(row_id, {})
	return found.duplicate(true)


func rows(table_name: String) -> Array:
	return _tables.get(table_name, []).duplicate(true)


func definition(definition_id: String) -> Dictionary:
	return row("definitions", definition_id)


func setting(setting_id: String, fallback: Variant = null, platform: String = "") -> Variant:
	var setting_row: Dictionary = _by_id.get("system_settings", {}).get(setting_id, {})
	if setting_row.is_empty():
		return fallback
	var value: Variant = setting_row.get("value", fallback)
	var resolved_platform := platform if not platform.is_empty() else current_platform()
	for override: Dictionary in _tables.get("platform_overrides", []):
		if override.get("platform") == resolved_platform and override.get("setting_id") == setting_id:
			return _convert_text(String(override.get("override_value", "")), String(setting_row.get("value_type", "string")), fallback)
	return value


func tuning_value(owner_definition_id: String, parameter: String, fallback: float = 0.0) -> float:
	for tuning_row: Dictionary in _tables.get("tuning", []):
		if tuning_row.get("owner_definition_id") == owner_definition_id and tuning_row.get("parameter") == parameter:
			return float(tuning_row.get("value", fallback))
	return fallback


func relations_from(source_definition_id: String, relation_type: String = "") -> Array:
	var found: Array = []
	for relation: Dictionary in _tables.get("relations", []):
		if relation.get("source_definition_id") != source_definition_id:
			continue
		if not relation_type.is_empty() and relation.get("relation_type") != relation_type:
			continue
		found.append(relation.duplicate(true))
	found.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.order) < int(right.order))
	return found


func text(key: String, locale: String = "") -> String:
	var resolved_locale := locale if not locale.is_empty() else String(setting("app.default_locale", "en"))
	var translation: Dictionary = _by_id.get("localization", {}).get(key, {})
	if translation.is_empty():
		return "[%s]" % key
	return String(translation.get(resolved_locale, translation.get("en", "[%s]" % key)))


func current_platform() -> String:
	if OS.has_feature("web"):
		return "web"
	if OS.has_feature("mobile"):
		return "mobile"
	return "desktop"


func _convert_text(value: String, value_type: String, fallback: Variant) -> Variant:
	match value_type:
		"int":
			return int(value) if value.is_valid_int() else fallback
		"float":
			return float(value) if value.is_valid_float() else fallback
		"bool":
			return value.to_lower() == "true" if value.to_lower() in ["true", "false"] else fallback
		_:
			return value
