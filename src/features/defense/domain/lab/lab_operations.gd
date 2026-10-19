extends RefCounted

const Config = preload("res://src/features/defense/domain/lab/lab_config.gd")
const Units = preload("res://src/features/defense/domain/lab/lab_units.gd")
const Edit = preload("res://src/features/defense/domain/lab/lab_unit_commands.gd")
var lab

func _init(owner) -> void:
	lab = owner

func submit(action: String, data: Dictionary) -> String:
	match action:
		"select":
			lab.selected_id = int(data.get("id", 0))
		"pause": lab.world.paused = bool(data.get("paused", not lab.world.paused))
		"advance":
			if not Config.finite_number(data.get("ticks"), 1, 62500) or float(data.ticks) != floor(float(data.ticks)):
				return "步数必须为1至62500的整数"
			lab.advance(int(data.ticks))
		"reset": return lab.load_config(lab.recipe)
		"configure":
			var value: Dictionary = lab.recipe.duplicate(true)
			for key in ["seed", "level", "wave", "legal_terms", "settings"]:
				if data.has(key):
					value[key] = data[key]
			return lab.load_config(value)
		"add": return add(data)
		"clear": return clear(data)
		"term": return term(data)
		"game":
			var intent = str(data.get("intent", ""))
			if not intent in ["choose", "refresh", "reward_close", "pause", "speed", "sound"]:
				return "测试场不支持该正式操作"
			return lab.world.submit(intent, data.get("payload", {}))
		_: return Edit.submit(lab, action, data)
	return ""

func add(data: Dictionary) -> String:
	var count = data.get("count", 1)
	if not Config.finite_number(count, 1, 300) or float(count) != floor(float(count)):
		return "每批数量必须为1至300的整数"
	var kind = str(data.get("kind", "enemy"))
	if kind == "hero" and count != 1:
		return "英雄每次召唤一名"
	var point = data.get("pos", [800, 700])
	if not point is Array or point.size() != 2 or not Config.finite_number(point[0], -2000, 4000) or not Config.finite_number(point[1], -2000, 4000):
		return "无效出生位置"
	var layout = str(data.get("layout", "point"))
	if not layout in ["point", "row", "column", "circle", "grid", "random"] or not Config.finite_number(data.get("spacing", 80), 0, 1000):
		return "无效排列或间距"
	var candidate: Dictionary = lab.recipe.duplicate(true)
	var key = 1
	for spec in candidate.units:
		key = maxi(key, int(spec.key) + 1)
	var additions: Array = []
	# Position sampling is separate from every production gameplay RNG stream.
	var rng_before: Dictionary = lab.world.rng.snapshot()
	for index in range(int(count)):
		var position = placement(Vector2(point[0], point[1]), layout, index, int(count), float(data.get("spacing", 80)))
		var spec = Config.unit(key + index, kind, int(data.get("template", 0)), [position.x, position.y])
		for field in ["survival", "actions", "attributes", "terms", "hp_ratio"]:
			if data.has(field):
				spec[field] = data[field]
		candidate.units.append(spec)
		additions.append(spec)
	var error = Config.validate(candidate, lab.catalog)
	if not error.is_empty():
		lab.world.rng.restore(rng_before)
		return error
	# Validate term dependencies transactionally before spawning any live actors.
	var trial = lab.get_script().new(lab.catalog)
	error = trial.load_config(candidate)
	trial.dispose()
	if not error.is_empty():
		lab.world.rng.restore(rng_before)
		return error
	lab.last_created.clear()
	for spec in additions:
		Units.spawn(lab.world, spec, lab.recipe.legal_terms)
		lab.last_created.append(Units.find(lab.world, int(spec.key)).id)
	lab.recipe = candidate
	lab.selected_id = int(lab.last_created.back())
	return ""

func placement(point: Vector2, layout: String, index: int, count: int, spacing: float) -> Vector2:
	var center = (count - 1) * 0.5
	match layout:
		"row": return point + Vector2((index - center) * spacing, 0)
		"column": return point + Vector2(0, (index - center) * spacing)
		"circle": return point + Vector2.from_angle(TAU * index / count) * spacing
		"grid":
			var columns = ceili(sqrt(count))
			return point + Vector2((index % columns - (columns - 1) * 0.5) * spacing, floori(float(index) / columns) * spacing)
		"random":
			var rng = lab.world.rng.stream("lab.placement")
			return point + Vector2(rng.next_int(10001) / 10000.0 - 0.5, rng.next_int(10001) / 10000.0 - 0.5) * spacing
	return point

func clear(data: Dictionary) -> String:
	var ids: Array = []
	var mode = str(data.get("scope", "selected"))
	if not mode in ["selected", "enemies", "heroes", "all", "template"]:
		return "未知清除范围"
	for actor in lab.world.units.values():
		if mode == "all" or (mode == "enemies" and actor.side == 2) or (mode == "heroes" and actor.kind == "hero") \
			or (mode == "selected" and actor.id == int(data.get("id", lab.selected_id))) \
			or (mode == "template" and actor.template == int(data.get("template", 0)) and actor.side == 2):
			ids.append(actor.id)
	var keys: Array = []
	for id in ids:
		keys.append(lab.world.units[id].get("lab_key", 0))
	for spec in lab.recipe.units:
		if mode == "all" or (mode == "enemies" and spec.kind != "hero") or (mode == "heroes" and spec.kind == "hero") \
			or (mode == "template" and spec.kind != "hero" and spec.template == int(data.get("template", 0))):
			keys.append(spec.key)
	Units.clear(lab.world, ids)
	lab.world.replacements = lab.world.replacements.filter(func(r): return not r.spec.key in keys)
	lab.recipe.units = lab.recipe.units.filter(func(spec): return not spec.key in keys)
	lab.world.selected.clear()
	for id in lab.world.heroes:
		for option in lab.world.units[id].upgrades:
			lab.world.selected[str(option)] = int(lab.world.selected.get(str(option), 0)) + 1
	if not lab.world.units.has(lab.selected_id):
		lab.selected_id = 0
	return ""

func term(data: Dictionary) -> String:
	var actor: Dictionary = lab.world.units.get(int(data.get("id", lab.selected_id)), {})
	if actor.is_empty() or actor.kind != "hero" or not actor.has("lab_key"):
		return "请先选择测试英雄"
	var count = data.get("count", 1)
	if not Config.finite_number(count, 0, 20) or float(count) != floor(float(count)):
		return "词条次数必须为0至20的整数"
	var next: Dictionary = lab.recipe.duplicate(true)
	for spec in next.units:
		if spec.key != actor.lab_key:
			continue
		if data.get("clear", false):
			spec.terms.clear()
		else:
			var key = str(int(data.get("term", 0)))
			if count == 0:
				spec.terms.erase(key)
			else:
				if data.get("prerequisites", false):
					var error = Config.prerequisites(lab.catalog, spec.terms, int(key), lab.catalog.record("heroes", spec.template).initial_options)
					if not error.is_empty():
						return error
				spec.terms[key] = int(count)
	var key: int = actor.lab_key
	var result: String = lab.load_config(next)
	if result.is_empty():
		lab.selected_id = int(Units.find(lab.world, key).id)
	return result
