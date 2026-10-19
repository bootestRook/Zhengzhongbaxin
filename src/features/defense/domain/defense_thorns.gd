class_name DefenseThorns
extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")
var w
var flowers: Array = []
var next_flower: int = 1

func _init(world) -> void:
	w = world

func reset() -> void:
	flowers.clear()
	next_flower = 1

func targets(owner: Dictionary, skill: Dictionary) -> Array:
	var result: Array = []
	for id in w.heroes:
		var unit: Dictionary = w.units[id]
		if not unit.dead and unit.id != owner.id and owner.pos.distance_to(unit.pos) <= float(skill.attack_range):
			result.append(unit)
	result.sort_custom(func(a, b):
		var health_a: float = U.hp(a) * U.stat(b, 1)
		var health_b: float = U.hp(b) * U.stat(a, 1)
		if health_a != health_b:
			return health_a < health_b
		var da: float = owner.pos.distance_squared_to(a.pos)
		var db: float = owner.pos.distance_squared_to(b.pos)
		return a.id < b.id if da == db else da < db)
	var config: Dictionary = skill.thorn_armor
	if result.is_empty() and config.self_fallback and not owner.dead:
		result.append(owner)
	return result.slice(0, int(config.targets))

func cast(owner: Dictionary, skill: Dictionary) -> bool:
	var selected = targets(owner, skill)
	if selected.is_empty():
		return false
	var config: Dictionary = skill.thorn_armor
	for target: Dictionary in selected:
		w.statuses.add(target, owner, int(config.armor_status), config.duration_ms)
		for state: Dictionary in target.statuses:
			if state.id == int(config.armor_status) and state.source == owner.id:
				state["thorn"] = config.duplicate(true)
		w.damage.heal(owner, target, U.stat(owner, 4) * float(config.heal_percent) / 100.0 * (1 + float(config.heal_bonus) / 100.0))
		var sanctuary = w.gems.thorn_cast_heal_max_pct(owner, target)
		if sanctuary > 0:
			w.damage.heal(owner, target, sanctuary)
		if config.extra_shield:
			w.statuses.add(target, owner, int(config.extra_status), config.duration_ms)
		w.cue("thorn_link", target.pos, {"res": "bullet:blood", "source_id": owner.id, "target_id": target.id, "duration": 400, "loop": false})
		if config.flowers:
			spawn(owner, target.pos + Vector2(65, 0), config)
	if config.follow:
		var available = owned(owner.id)
		for i in range(mini(selected.size(), available.size())):
			var target: Dictionary = selected[i]
			available[i].target = target.id
			available[i].pos = target.pos + Vector2(65, 0)
			w.damage.heal(owner, target, U.stat(target, 1) * 0.1)
			w.statuses.add(target, owner, int(config.guard_status), float(config.guard_ms))
	return true

func direct_armors(source: Dictionary, target: Dictionary, context: Dictionary) -> Array:
	if source.is_empty() or source.side == target.side or context.get("kind", "attack") not in ["attack", "skill"]:
		return []
	var result: Array = []
	for state: Dictionary in target.statuses:
		if state.has("thorn") and w.time_ms < state.expires:
			result.append(state.duplicate(true))
	return result

func retaliate(attacker: Dictionary, armors: Array) -> void:
	for state: Dictionary in armors:
		var owner: Dictionary = w.units.get(state.source, {})
		if owner.is_empty() or attacker.dead:
			continue
		var config: Dictionary = state.thorn
		if config.slow:
			w.statuses.add(attacker, owner, int(config.slow_status), float(config.slow_ms))
		nature_hit(owner, attacker, float(config.retaliate_percent), false)

func ended(target: Dictionary, state: Dictionary, reason: String) -> void:
	if not state.has("thorn") or not state.thorn.burst or reason not in ["expired", "broken"]:
		return
	var owner: Dictionary = w.units.get(state.source, {})
	if owner.is_empty():
		return
	for enemy: Dictionary in area(owner, target.pos, float(state.thorn.burst_radius)):
		w.statuses.add(enemy, owner, int(state.thorn.stun_status), float(state.thorn.burst_stun_ms))
	w.cue("effect", target.pos, {"res": "hero2:wrapBoom", "duration": 600, "loop": false, "scale": 1.2})

func owned(owner_id: int) -> Array:
	return flowers.filter(func(f): return f.owner == owner_id and w.time_ms < f.expires)

func spawn(owner: Dictionary, pos: Vector2, config: Dictionary) -> void:
	var existing = owned(owner.id)
	if existing.size() >= int(config.flower_limit):
		existing.sort_custom(func(a, b): return a.id < b.id if a.expires == b.expires else a.expires < b.expires)
		flowers.erase(existing[0])
	flowers.append({"id": next_flower, "owner": owner.id, "pos": pos, "target": 0,
		"started": w.time_ms, "expires": w.time_ms + int(config.flower_duration_ms),
		"next": w.time_ms + int(config.flower_interval_ms), "pulse_at": -1000, "config": config.duplicate(true)})
	next_flower += 1

func tick() -> void:
	for flower: Dictionary in flowers.duplicate():
		var target: Dictionary = w.units.get(flower.target, {})
		if not target.is_empty() and not target.dead:
			flower.pos = target.pos + Vector2(65, 0)
		var config: Dictionary = flower.config
		var owner: Dictionary = w.units.get(flower.owner, {})
		while flower.next <= mini(w.time_ms, flower.expires):
			flower.pulse_at = flower.next
			flower.next += int(config.flower_interval_ms)
			if owner.is_empty():
				continue
			for enemy: Dictionary in area(owner, flower.pos, float(config.flower_radius)):
				nature_hit(owner, enemy, float(config.flower_damage_percent), true)
				if not enemy.dead:
					w.statuses.add(enemy, owner, int(config.root_status), float(config.root_ms))
			w.cue("effect", flower.pos, {"res": "hero2:wrapBoom", "duration": 500, "loop": false, "scale": 0.65})
		if w.time_ms >= flower.expires:
			flowers.erase(flower)

func nature_hit(owner: Dictionary, enemy: Dictionary, percent: float, triggers: bool) -> void:
	var amount = U.stat(owner, 4) * percent / 100.0 * maxf(0, 1 + U.stat(owner, 12) / 100.0)
	w.damage.hit(owner, enemy, amount, true, triggers, {"kind": "skill" if triggers else "retaliation", "tags": str(owner.damage_type).split(";")})

func area(owner: Dictionary, pos: Vector2, radius: float) -> Array:
	var result: Array = []
	for unit: Dictionary in w.units.values():
		if not unit.dead and unit.side != owner.side and not w.targets.hidden_enemy(owner, unit) and pos.distance_to(unit.pos) <= radius + float(unit.body_radius):
			result.append(unit)
	return result

func snapshot() -> Array:
	var result: Array = []
	for flower: Dictionary in flowers:
		var template = int(flower.config.flower_template)
		var motion: Dictionary = w.combat.actors["soldierData:%d" % template]
		result.append({"id": flower.id, "owner": flower.owner, "pos": flower.pos,
			"res": w.catalog.record("summons", template).res, "started": flower.started,
			"pulse_at": flower.pulse_at, "expires": flower.expires, "next": flower.next,
			"pivot": Vector2(motion.pivot[0], motion.pivot[1]), "frames": motion.frames})
	return result
