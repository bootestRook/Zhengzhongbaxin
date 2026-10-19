extends RefCounted

const Config = preload("res://src/features/defense/domain/lab/lab_config.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

static func submit(lab, action: String, data: Dictionary) -> String:
	if action == "wall":
		if not Config.finite_number(data.get("hp"), 0, lab.world.wall_max):
			return "雕像生命超出范围"
		lab.world.wall_hp = float(data.hp)
		return ""
	var actors: Array = []
	var scope = str(data.get("scope", "selected"))
	if not scope in ["selected", "enemies", "template"]:
		return "未知作用范围"
	for actor in lab.world.units.values():
		if (scope == "selected" and actor.id == int(data.get("id", lab.selected_id))) \
			or (scope == "enemies" and actor.side == 2) \
			or (scope == "template" and actor.side == 2 and actor.template == int(data.get("template", -1))):
			actors.append(actor)
	if actors.is_empty():
		return "请先选择有效单位"
	for actor in actors:
		var error = validate(lab, actor, action, data)
		if not error.is_empty():
			return error
	for actor in actors:
		apply(lab, actor, action, data)
		lab.world.record("manual", {"action": action, "target": actor.id, "payload": data})
	return ""

static func validate(lab, actor: Dictionary, action: String, data: Dictionary) -> String:
	if actor.dead and action != "revive":
		return "单位已经死亡；可等待正常复活，或使用测试复活"
	match action:
		"attribute":
			var key = str(data.get("attribute", ""))
			if not lab.catalog.records("attributes").has(key) or not Config.finite_number(data.get("value"), 1 if key == "1" else 0, 1000000000):
				return "无效属性或数值"
		"health":
			if not Config.finite_number(data.get("ratio"), 0.000001, 1): return "生命比例必须大于0且不超过1"
		"survival":
			if not data.get("mode") in ["normal", "immortal", "invulnerable"]: return "无效生存模式"
		"actions":
			for key in ["move", "attack", "skill"]:
				if not data.get(key) is bool: return "行为开关必须为布尔值"
		"position":
			if not data.get("pos") is Array or data.pos.size() != 2: return "无效位置"
			for value in data.pos:
				if not Config.finite_number(value, -2000, 4000): return "位置超出范围"
		"status":
			if lab.catalog.record("statuses", int(data.get("status", 0))).is_empty() or not Config.finite_number(data.get("duration_ms"), 16, 3600000): return "无效状态或持续时间"
			if not Config.finite_number(data.get("stacks", 1), 1, 100): return "状态次数必须为1至100"
			var source: Dictionary = lab.world.units.get(int(data.get("source", actor.id)), {})
			if source.is_empty() or source.dead: return "状态来源无效"
		"shield":
			if not Config.finite_number(data.get("value"), 0, 1000000000): return "无效护盾值"
		"kill":
			if actor.get("lab_survival", "normal") != "normal": return "击杀验证须先切换为正常生命"
			if int(data.get("source", 0)) != 0 and not lab.world.units.has(int(data.source)): return "击杀来源不存在"
		"ready", "clear_status", "weaken": pass
		"revive":
			if actor.kind != "hero" or not actor.dead: return "仅支持复活已死亡英雄"
		_: return "未知测试操作：" + action
	return ""

static func apply(lab, actor: Dictionary, action: String, data: Dictionary) -> void:
	match action:
		"attribute":
			var key = str(data.attribute)
			actor.core.attributes.set_base_value(key, float(data.value))
			if key == "1": actor.core.attributes.set_value("hp", minf(U.hp(actor), U.stat(actor, 1)))
			update_spec(lab, actor, "attribute", {"key": key, "value": float(data.value)})
		"health":
			actor.core.attributes.set_value("hp", U.stat(actor, 1) * float(data.ratio))
			update_spec(lab, actor, "hp_ratio", float(data.ratio))
		"weaken":
			actor["lab_survival"] = "normal"
			actor.core.attributes.set_value("hp", 1)
			update_spec(lab, actor, "survival", "normal")
		"survival":
			actor["lab_survival"] = data.mode
			update_spec(lab, actor, "survival", data.mode)
		"actions":
			actor["lab_actions"] = {"move": data.move, "attack": data.attack, "skill": data.skill}
			update_spec(lab, actor, "actions", actor.lab_actions)
		"position":
			actor.pos = Vector2(data.pos[0], data.pos[1])
			actor.home = actor.pos
			actor.entering = false
			actor.guard_return = false
			actor.back_lock = false
			update_spec(lab, actor, "pos", data.pos)
			lab.world.space.rebuild()
		"ready":
			actor.attack_at = lab.world.time_ms
			for state in actor.skills.values(): state.next = lab.world.time_ms
		"status":
			var source: Dictionary = lab.world.units.get(int(data.get("source", actor.id)), actor)
			for _i in range(int(data.get("stacks", 1))): lab.world.statuses.add(actor, source, int(data.status), float(data.duration_ms))
		"clear_status":
			for state in actor.statuses.duplicate(): lab.world.statuses.remove(actor, state, "cleared")
		"shield":
			# Manual shield is independent of shields owned by status instances.
			var previous = float(actor.get("lab_shield", 0))
			var next = float(data.value)
			actor.shield = maxf(0, actor.shield - previous) + next
			actor["lab_shield"] = next
		"kill": lab.world.damage.defeat(actor, lab.world.units.get(int(data.get("source", 0)), {}))
		"revive":
			actor.revive_at = lab.world.time_ms
			lab.world.factory.lifecycle()

static func update_spec(lab, actor: Dictionary, field: String, value: Variant) -> void:
	if not actor.has("lab_spec"):
		return
	for spec in lab.recipe.units:
		if spec.key != actor.lab_key: continue
		if field == "attribute": spec.attributes[value.key] = value.value
		else: spec[field] = value.duplicate(true) if value is Array or value is Dictionary else value
		actor.lab_spec = spec.duplicate(true)
