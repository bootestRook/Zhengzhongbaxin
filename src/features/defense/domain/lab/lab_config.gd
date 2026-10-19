extends RefCounted

static func empty() -> Dictionary:
	return {"version": 1, "seed": 53, "level": 1, "wave": 1, "legal_terms": true,
		"settings": {"spawn": false, "progression": false, "respawn": false}, "units": []}

static func unit(key: int, kind: String, template: int, pos: Array) -> Dictionary:
	return {"key": key, "kind": kind, "template": template, "pos": pos.duplicate(), "terms": {}, "attributes": {},
		"hp_ratio": 1.0, "survival": "normal", "actions": {"move": true, "attack": true, "skill": true}}

static func finite_number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func validate(value: Variant, catalog) -> String:
	if not value is Dictionary or value.get("version") != 1:
		return "测试配置版本必须为1"
	for key in ["seed", "level", "wave"]:
		if not finite_number(value.get(key), 1, 2147483647) or float(value[key]) != floor(float(value[key])):
			return "无效配置：" + key
	if catalog.record("levels", int(value.level)).is_empty() or value.wave > 20:
		return "关卡或波次不存在"
	if not value.get("legal_terms") is bool or not value.get("settings") is Dictionary:
		return "缺少词条模式或环境设置"
	for key in ["spawn", "progression", "respawn"]:
		if not value.settings.get(key) is bool:
			return "无效环境设置：" + key
	if not value.get("units") is Array or value.units.size() > 500:
		return "配置最多支持500个单位"
	var keys: Array = []
	var heroes: Array = []
	for spec in value.units:
		if not spec is Dictionary:
			return "单位配置必须是对象"
		var error = validate_unit(spec, catalog)
		if not error.is_empty():
			return error
		if int(spec.key) in keys:
			return "单位编号重复"
		keys.append(int(spec.key))
		if spec.kind == "hero":
			if int(spec.template) in heroes or heroes.size() >= 5:
				return "英雄不可重复，最多五名"
			heroes.append(int(spec.template))
	return ""

static func validate_unit(spec: Dictionary, catalog) -> String:
	if not finite_number(spec.get("key"), 1, 1000000) or not spec.get("kind") in ["hero", "enemy", "elite", "boss"]:
		return "无效单位编号或类型"
	if not finite_number(spec.get("template"), 1, 1000000):
		return "无效模板编号"
	if float(spec.key) != floor(float(spec.key)) or float(spec.template) != floor(float(spec.template)):
		return "单位和模板编号必须为整数"
	var definition = catalog.record("heroes" if spec.kind == "hero" else "monsters", int(spec.template))
	if definition.is_empty() or (spec.kind == "hero" and not catalog.available_heroes().has(int(spec.template))):
		return "模板不存在或英雄尚未开放"
	if not spec.get("pos") is Array or spec.pos.size() != 2:
		return "位置必须包含x和y"
	for coordinate in spec.pos:
		if not finite_number(coordinate, -2000, 4000):
			return "位置超出测试范围"
	if not spec.get("survival") in ["normal", "immortal", "invulnerable"] or not finite_number(spec.get("hp_ratio"), 0.000001, 1):
		return "无效生命模式或生命比例"
	if not spec.get("actions") is Dictionary or not spec.get("attributes") is Dictionary or not spec.get("terms") is Dictionary:
		return "缺少单位行为、属性或词条配置"
	for action in ["move", "attack", "skill"]:
		if not spec.actions.get(action) is bool:
			return "无效行为开关"
	for attribute in spec.attributes:
		if not catalog.records("attributes").has(str(attribute)) or not finite_number(spec.attributes[attribute], 1 if str(attribute) == "1" else 0, 1000000000):
			return "无效属性：" + str(attribute)
	for term in spec.terms:
		var option = catalog.record("options", int(term))
		if spec.kind != "hero" or option.is_empty() or not option.get("type", []).has(int(spec.template)) or int(term) in definition.get("initial_options", []):
			return "词条不属于该英雄，或已随招募获得：" + str(term)
		if not finite_number(spec.terms[term], 1, 20) or float(spec.terms[term]) != floor(float(spec.terms[term])):
			return "词条次数必须为1至20的整数"
	return ""

static func normalize(value: Dictionary) -> Dictionary:
	# JSON numbers arrive as floats; IDs must have the same type as live IDs.
	var result = value.duplicate(true)
	for key in ["version", "seed", "level", "wave"]: result[key] = int(result[key])
	for spec in result.units:
		spec.key = int(spec.key)
		spec.template = int(spec.template)
		for term in spec.terms: spec.terms[term] = int(spec.terms[term])
	return result

static func apply_terms(world, unit_value: Dictionary, terms: Dictionary, legal: bool) -> String:
	var remaining = terms.duplicate(true)
	while not remaining.is_empty():
		var progressed = false
		for key in remaining.keys():
			var option = world.catalog.record("options", int(key))
			if not legal or world.choices.eligible(option, unit_value):
				world.upgrades.apply(unit_value, int(key))
				remaining[key] -= 1
				if remaining[key] == 0:
					remaining.erase(key)
				progressed = true
		if not progressed:
			return "词条前置、互斥或次数不合法：" + str(remaining.keys())
	return ""

static func prerequisites(catalog, terms: Dictionary, option_id: int, roots: Array, visited: Array = []) -> String:
	if option_id in roots:
		return ""
	if option_id in visited:
		return "词条前置存在循环"
	var option = catalog.record("options", option_id)
	if option.is_empty():
		return "词条不存在"
	visited = visited.duplicate()
	visited.append(option_id)
	var conditions: Array = option.get("premise1", []).duplicate(true)
	var alternatives: Array = option.get("premise2", [])
	if not alternatives.is_empty():
		var satisfied = false
		for item in alternatives:
			satisfied = satisfied or int(terms.get(str(int(item[0])), 1 if int(item[0]) in roots else 0)) >= int(item[1])
		if not satisfied:
			conditions.append(alternatives[0])
	for condition in conditions:
		if int(condition[1]) <= 0 or int(condition[0]) in roots:
			continue
		var error = prerequisites(catalog, terms, int(condition[0]), roots, visited)
		if not error.is_empty():
			return error
		terms[str(int(condition[0]))] = maxi(int(terms.get(str(int(condition[0])), 0)), int(condition[1]))
	return ""
