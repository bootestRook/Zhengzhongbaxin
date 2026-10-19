class_name DefenseSnapshot
extends RefCounted

const Statue = preload("res://src/features/defense/domain/defense_statue.gd")

const U = preload("res://src/features/defense/domain/defense_units.gd")
const Geometry = preload("res://src/features/defense/domain/defense_projectile_geometry.gd")

static func make(w) -> Dictionary:
	var actors: Array = []
	var roster: Array = []
	for u: Dictionary in w.units.values():
		var actor = {"id": u.id, "template": u.template, "kind": u.kind, "side": u.side,
			"res": u.res, "name": u.name, "pos": u.pos, "action": "die" if u.dead else u.action,
			"action_at": u.action_at, "facing": u.facing, "dead": u.dead, "hp": U.hp(u), "max_hp": U.stat(u, 1),
			"health_bars": int(u.get("health_bars", 1)),
			"shield": u.shield, "revive": maxi(0, u.revive_at - w.time_ms), "statuses": [],
			"pivot": u.motion.get("pivot", [0.5, 0.85]), "hp_offset": u.motion.get("hp_offset", [0, -90]),
			"frames": u.motion.get("frames", {}).get("die" if u.dead else u.action, []), "action_rate": u.action_rate}
		actor["hidden"] = int(u.get("hidden_until", 0)) > w.time_ms
		actor["taunted"] = not u.dead and not w.damage.protection.taunt_ended(u, {"source": u.taunt}) and not w.targets.hidden_enemy(u, w.units[u.taunt])
		actor["taunt_started"] = int(u.get("taunt_started", 0))
		actor["overlays"] = u.motion.overlays
		actor["tint"] = "#FFFFFFFF"
		actor["status_effects"] = []
		actor["tombstone"] = u.dead and u.kind == "hero" and u.death_finished
		actor["death_age"] = w.time_ms - u.action_at if u.dead else 0
		if u.dead and u.kind != "hero" and actor.frames.is_empty():
			var pose: Dictionary = u.death_pose
			actor.action = pose.action
			actor["frame_elapsed"] = pose.elapsed
			actor.frames = u.motion.get("frames", {}).get(pose.action, [])
		for status in u.statuses:
			actor.statuses.append({"id": status.id, "stacks": status.stacks})
			var definition: Dictionary = w.statuses.definitions[str(status.id)]
			if definition.has("colorChange"):
				actor.tint = definition.colorChange
			for effect in definition.get("effect", []):
				if w.combat.buff_effects.has(str(effect[0])):
					actor.status_effects.append(status_effect(w, u, status, effect))
		actors.append(actor)
		if u.kind == "hero":
			actor["stats"] = u.stats.duplicate()
			actor["attributes"] = {}
			for key in w.attribute_defs:
				actor.attributes[key] = U.stat(u, int(key))
			actor["upgrades"] = u.upgrades.duplicate()
			actor["skills"] = []
			for option_id in w.catalog.record("heroes", u.template).initial_options:
				actor.skills.append(skill_snapshot(w, u, int(option_id)))
			roster.append(actor)
	actors.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	var previous = 0
	var threshold = 0
	if not w.level.is_empty():
		for i in range(w.stage + 1):
			previous = threshold
			threshold += int(w.level.waves[i].count)
	var missiles: Array = []
	for p in w.missiles:
		var logic_scale = Geometry.scale_for(p)
		var render_scale = logic_scale * p.scale
		if p.kind == 9:
			render_scale = logic_scale * Vector2(1 if p.direction.x > 0 else -1, 1)
		missiles.append({"id": p.id, "owner": p.owner, "direction": p.direction, "pos": p.pos, "from": p.from, "to": p.to, "kind": p.kind, "res": p.res, "scale": p.scale, "start": p.start, "radius": p.radius,
			"rotation": p.rotation, "pivot": p.get("shape", {}).get("basePivot", {"x": 0.5, "y": 0.5}), "layer": p.layer,
			"render_scale": render_scale, "logic_scale": logic_scale, "tint": str(p.skill.get("visual_tint", "#ffffff")),
			"fire_visual": p.skill.get("fire_visual", false), "fire_phase": p.skill.get("fire_phase", ""),
			"ice_rain": p.skill.has("ice_rain"),
			"fire_secondary": p.skill.get("fire_secondary", false), "fire_duration": p.get("life", 500),
			"special_res": str(p.skill.get("res", "bullet")) + ":" + str(p.skill.movie_special) if p.skill.has("movie_special") else ""})
	var visuals: Array = w.visuals.duplicate(true)
	for effect: Dictionary in visuals:
		if effect.kind == "skill_text" and w.units.has(effect.source_id):
			effect.pos = w.units[effect.source_id].pos
		if effect.kind == "thorn_link":
			effect["from_pos"] = w.targets.attack_point(w.units[effect.source_id])
			effect["to_pos"] = w.targets.attack_point(w.units[effect.target_id])
	return {"phase": w.phase, "level": w.level_id, "chapter": ceili(w.level_id / 10.0),
		"paused": w.paused, "speed": w.speed, "muted": w.muted, "time": w.time_ms,
		"wave": w.spawn_wave, "wave_count": w.rules.wave_count, "stage": mini(w.stage + 1, w.rules.max_level), "kills": w.kills, "encounters_cleared": w.encounters_cleared.duplicate(),
		"progress": clampf(float(w.kills - previous) / maxf(1, threshold - previous), 0, 1),
		"wall_hp": w.wall_hp, "wall_max": w.wall_max, "won": w.won, "result_level": w.result_level, "deaths": w.deaths,
		"statue_pos": Statue.POSITION, "equipment": w.equipment.snapshot() if w.phase == "home" else {},
		"result": w.result.duplicate(true),
		"actors": actors, "heroes": roster, "missiles": missiles, "visuals": visuals, "flowers": w.skills.thorns.snapshot(),
		"reward": w.loot.snapshot(), "offers": w.offers.duplicate(true), "choice_kind": w.choice_kind,
		"refresh_left": w.refresh_left, "history": w.history.duplicate(true), "world_offset": w.combat.world.canvas_offset}

static func status_effect(w, unit: Dictionary, state: Dictionary, effect: Array) -> Dictionary:
	var data: Dictionary = w.combat.buff_effects[str(effect[0])]
	var dimensions: Dictionary = data.get("collisionSize", data.baseSize)
	var mode = int(effect[1]) if effect.size() > 1 else 0
	var motion: Dictionary = unit.motion
	var scaling = Vector2.ONE * minf(motion.base_size[0], motion.base_size[1]) / maxf(dimensions.x, dimensions.y)
	var offset = Vector2(motion.buff_offset[0] * unit.facing, motion.buff_offset[1])
	var color := Color.WHITE
	if mode == 1:
		scaling = Vector2(motion.buff_size[0] / dimensions.x, motion.buff_size[1] / dimensions.y)
	elif mode in [2, 3]:
		scaling = Vector2.ONE * motion.shadow_size[0] / dimensions.x
		offset = Vector2.ZERO
	elif mode == 4:
		scaling = Vector2.ONE * 200 * motion.hp_scale[0] / dimensions.x
		offset = Vector2(motion.hp_offset[0], motion.hp_offset[1])
	if str(effect[0]) == "stun3":
		# Use a compact, high-contrast star ring that stays readable above the unit.
		# It remains independent of the unit's body or HP-bar scale.
		scaling = Vector2.ONE * 0.18
		color = Color("#63e7ff")
		offset += Vector2(0, -14)
	return {"res": "bulletStatus:" + str(effect[0]), "pivot": Vector2(data.basePivot.x, data.basePivot.y),
		"scale": scaling, "offset": offset, "start": state.started, "down": mode in [3, 5], "tint": color}

static func skill_snapshot(w, unit: Dictionary, option_id: int) -> Dictionary:
	var initial = w.catalog.record("options", option_id)
	var level = 0
	for id in unit.upgrades:
		if id == option_id or int(w.catalog.record("options", id).get("root_option", 0)) == option_id:
			level += 1
	var trigger_id = int(initial.trigger_skill)
	var state: Dictionary = unit.skills.get(trigger_id, {})
	if state.get("data", {}).get("fireball", {}).get("upgraded", false) or state.get("data", {}).get("ice_arrows", {}).get("upgraded", false):
		for id in unit.upgrades:
			var option = w.catalog.record("options", int(id))
			if option.get("fireball_mod", {}).get("upgraded", false) or option.get("ice_mod", {}).get("upgraded", false):
				initial = option
	var remaining = maxi(0, int(state.get("next", 0)) - w.time_ms)
	var total = maxi(1, int(state.get("data", {}).get("cd", 0)))
	if trigger_id == 0 or (not state.is_empty() and state.data.get("triggerOpp", []).has("18")):
		total = w.ai.period(unit)
		remaining = maxi(0, unit.attack_at - w.time_ms)
	var data: Dictionary = state.get("data", {})
	var cast_range = float(data.get("attack_range", 0))
	if data.has("cast_range"):
		cast_range = float(data.cast_range)
	return {"option": option_id, "res": initial.icon_res, "title": initial.title, "description": initial.description,
		"level": maxi(1, level), "cooldown": remaining, "total": total, "cast_range": maxf(0, cast_range)}
