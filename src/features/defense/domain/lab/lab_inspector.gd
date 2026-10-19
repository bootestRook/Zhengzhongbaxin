extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")

static func unit_snapshot(world, id: int) -> Dictionary:
	var actor: Dictionary = world.units.get(id, {})
	if actor.is_empty():
		return {}
	var result = {"id": id, "key": actor.get("lab_key", 0), "name": display_name(actor), "kind": actor.kind,
		"template": actor.template, "pos": [actor.pos.x, actor.pos.y], "dead": actor.dead, "target": actor.target,
		"hp": U.hp(actor), "max_hp": U.stat(actor, 1), "shield": actor.shield, "action": actor.action,
		"survival": actor.get("lab_survival", "normal"), "actions": actor.get("lab_actions", {"move": true, "attack": true, "skill": true}).duplicate(),
		"stats": actor.stats.duplicate(), "kills": actor.kills, "hits": actor.hits, "skills": [], "statuses": [],
		"attributes": [], "terms": actor.upgrades.duplicate(), "revive_ms": maxi(0, actor.revive_at - world.time_ms)}
	for key in world.attribute_defs:
		result.attributes.append({"id": key, "name": str(world.attribute_defs[key].get("title", key)),
			"base": actor.core.attributes.base_value(key), "value": U.stat(actor, int(key)), "trace": actor.core.attributes.aggregation_trace(key)})
	for key in actor.skills:
		var state: Dictionary = actor.skills[key]
		result.skills.append({"id": key, "cooldown_ms": maxi(0, state.next - world.time_ms), "count": state.count,
			"hunt_ready": state.get("hunt_ready", false), "data": state.data.duplicate(true)})
	for state in actor.statuses:
		result.statuses.append({"id": state.id, "source": state.source, "stacks": state.stacks,
			"remaining_ms": maxi(0, state.expires - world.time_ms), "shield": state.shield_remaining})
	return result

static func state(world) -> Dictionary:
	var actors: Array = []
	for id in world.units:
		actors.append(unit_snapshot(world, id))
	return {"time_ms": world.time_ms, "phase": world.phase, "wall_hp": world.wall_hp, "kills": world.kills,
		"units": actors, "missiles": world.missiles.size(), "flowers": world.skills.thorns.flowers.size(),
		"queue": world.skills.queue.size(), "diagnostics": world.diagnostics.duplicate(), "rng": world.rng.snapshot()}

static func roster(world) -> Array:
	var result: Array = []
	for actor in world.units.values():
		result.append({"id": actor.id, "template": actor.template, "name": display_name(actor), "kind": actor.kind,
			"hp": U.hp(actor), "max_hp": U.stat(actor, 1), "dead": actor.dead, "survival": actor.get("lab_survival", "normal")})
	return result

static func display_name(actor: Dictionary) -> String:
	return str(actor.name) if not str(actor.name).is_empty() else "模板 %d" % actor.template

static func geometry(world, selected: int) -> Dictionary:
	var body = preload("res://src/features/defense/domain/defense_attack_geometry.gd")
	var projectile = preload("res://src/features/defense/domain/defense_projectile_geometry.gd")
	var result = {"actors": [], "missiles": [], "circles": [], "target_line": []}
	for actor in world.units.values():
		if actor.dead: continue
		result.actors.append({"id": actor.id, "pos": actor.pos, "body": body.shape(actor, "body", 0),
			"attack": body.shape(actor, "attack_box", -float(actor.motion.get("attack_angle", 0)) * actor.facing * PI / 180), "survival": actor.get("lab_survival", "normal")})
		if actor.id != selected: continue
		result.circles.append({"center": actor.pos, "radius": U.stat(actor, 26), "kind": "attack"})
		for option_id in world.catalog.record("heroes", actor.template).get("initial_options", []) if actor.kind == "hero" else []:
			var snapshot = preload("res://src/features/defense/domain/defense_snapshot.gd").skill_snapshot(world, actor, int(option_id))
			result.circles.append({"center": actor.pos, "radius": snapshot.cast_range, "kind": "cast"})
		if world.units.has(actor.target): result.target_line = [actor.pos, world.units[actor.target].pos]
	for missile in world.missiles:
		result.missiles.append({"pos": missile.pos, "from": missile.from, "to": missile.to,
			"shape": projectile.shape(missile) if missile.has("shape") else PackedVector2Array(), "radius": missile.radius})
	return result
