class_name DefenseCatalog
extends RefCounted

var _data: Dictionary = {}
var error: String = ""

func load_default() -> String:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/generated/defense_catalog.json"))
	if not raw is Dictionary or int(raw.get("schema_version", 0)) != 14 or int(raw.get("rules", {}).get("schema_version", 0)) != 6:
		error = "战斗资料无法读取，请重新生成数据。"
		return error
	_data = normalize(raw)
	return ""

static func normalize(value: Variant) -> Variant:
	if value is float and value == floor(value):
		return int(value)
	if value is Array:
		for i in range(value.size()):
			value[i] = normalize(value[i])
	elif value is Dictionary:
		for key in value:
			value[key] = normalize(value[key])
	return value

func record(table: String, key: int) -> Dictionary:
	return _data.get(table, {}).get(str(key), {}).duplicate(true)

func records(table: String) -> Dictionary:
	return _data.get(table, {}).duplicate(true)

func level_ids() -> Array:
	var ids: Array = []
	for key in _data.get("levels", {}).keys():
		ids.append(int(key))
	ids.sort()
	return ids

func art() -> Dictionary:
	return _data.get("art", {}).duplicate(true)

func baseline() -> Dictionary:
	return _data.get("baseline", {}).duplicate(true)

func spawn_policy() -> Dictionary:
	return _data.spawn_policy.duplicate(true)

func combat() -> Dictionary:
	return _data.combat.duplicate(true)

func rules() -> Dictionary:
	return _data.rules.duplicate(true)

func available_heroes() -> Array:
	var result: Array = []
	for value: Dictionary in _data.heroes.values():
		if value.available and _data.rules.unlocked_heroes.has(value.id):
			result.append(value.id)
	result.sort()
	return result

static func numbers(value: Variant) -> Array:
	var out: Array = []
	if value is Array:
		for part in value:
			out.append(float(part))
	else:
		for part: String in str(value).split(":"):
			out.append(float(part))
	return out

static func number(value: Variant, index: int = 0, default: float = 0.0) -> float:
	var values = numbers(value)
	return float(values[index]) if index >= 0 and index < values.size() else default

static func percent_value(base: float, value: Variant) -> float:
	var parts = numbers(value)
	if parts.size() > 1 and int(parts[1]) == 1:
		return base * float(parts[0]) / 100.0
	return float(parts[0]) if not parts.is_empty() else 0.0
