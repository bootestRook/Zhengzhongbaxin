extends RefCounted

const Config = preload("res://src/features/defense/domain/lab/lab_config.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

static func spawn(world, spec: Dictionary, legal: bool) -> String:
	var actor: Dictionary
	var pos = Vector2(spec.pos[0], spec.pos[1])
	if spec.kind == "hero":
		if not world.factory.add_hero(int(spec.template)):
			return "无法召唤该英雄"
		actor = world.units[world.heroes.back()]
	else:
		actor = world.factory.create(spec.kind, int(spec.template), pos, 2)
	if actor.is_empty():
		return "单位创建失败"
	actor["lab_key"] = int(spec.key)
	actor["lab_spec"] = spec.duplicate(true)
	actor["lab_survival"] = spec.survival
	actor["lab_actions"] = spec.actions.duplicate(true)
	actor.pos = pos
	actor.home = pos
	actor.entering = false
	actor.guard_return = false
	for unit_value in world.units.values():
		if unit_value.has("lab_spec") and unit_value.kind == "hero":
			unit_value.home = Vector2(unit_value.lab_spec.pos[0], unit_value.lab_spec.pos[1])
	for key in spec.attributes:
		actor.core.attributes.set_base_value(str(key), float(spec.attributes[key]))
	var error = Config.apply_terms(world, actor, spec.terms, legal)
	if not error.is_empty():
		return error
	actor.core.attributes.set_value("hp", U.stat(actor, 1) * float(spec.hp_ratio))
	world.space.rebuild()
	world.record("spawn", {"target": actor.id, "key": spec.key, "template": spec.template, "kind": spec.kind})
	return ""

static func clear(world, ids: Array) -> void:
	# Clear the dependency closure without calling defeat or creating rewards.
	var removing = ids.duplicate()
	var keys: Array = []
	var changed = true
	while changed:
		changed = false
		for unit_value in world.units.values():
			if unit_value.owner in removing and not unit_value.id in removing:
				removing.append(unit_value.id)
				changed = true
	for id in removing:
		var unit_value: Dictionary = world.units.get(id, {})
		if unit_value.is_empty():
			continue
		keys.append(unit_value.get("lab_key", 0))
		for state in unit_value.statuses.duplicate():
			world.statuses.remove(unit_value, state, "cleared")
		world.space.release(unit_value)
		world.heroes.erase(id)
		world.units.erase(id)
		world.core.remove_entity(str(id))
		world.record("cleared", {"target": id})
	for unit_value in world.units.values():
		for key in ["target", "taunt", "blocked_by", "force_boss"]:
			if unit_value.get(key, 0) in removing:
				unit_value[key] = 0
		for state in unit_value.statuses.duplicate():
			if state.source in removing:
				world.statuses.remove(unit_value, state, "cleared")
		unit_value.attack_events = unit_value.attack_events.filter(func(e): return not e.target in removing)
		unit_value.pending_actions = unit_value.pending_actions.filter(func(e): return not e.target in removing)
		if unit_value.get("forced_motion", {}).get("owner", 0) in removing:
			unit_value.erase("forced_motion")
		for state in unit_value.skills.values():
			state.summons = state.summons.filter(func(id): return not id in removing)
	world.missiles = world.missiles.filter(func(p): return not p.owner in removing and not p.target in removing)
	world.skills.queue = world.skills.queue.filter(func(e): return not e.owner in removing and not e.target in removing)
	world.skills.fireball.charges = world.skills.fireball.charges.filter(func(c): return not c.owner in removing)
	world.skills.thorns.flowers = world.skills.thorns.flowers.filter(func(f): return not f.owner in removing and not f.get("target", 0) in removing)
	world.visuals = world.visuals.filter(func(v): return not v.get("source_id", 0) in removing and not v.get("target_id", 0) in removing)
	world.pending = world.pending.filter(func(id): return not id in removing)
	world.offers = world.offers.filter(func(o): return not o.get("owner", 0) in removing)
	world.replacements = world.replacements.filter(func(r): return not r.spec.key in keys)
	world.space.rebuild()
	world.navigation.rebuild()

static func find(world, key: int) -> Dictionary:
	for actor in world.units.values():
		if int(actor.get("lab_key", 0)) == key and not actor.dead:
			return actor
	for actor in world.units.values():
		if int(actor.get("lab_key", 0)) == key:
			return actor
	return {}
