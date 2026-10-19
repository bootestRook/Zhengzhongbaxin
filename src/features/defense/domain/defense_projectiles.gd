class_name DefenseProjectiles
extends RefCounted

const C = preload("res://src/features/defense/domain/defense_catalog.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const Motion = preload("res://src/features/defense/domain/defense_projectile_motion.gd")
const Effects = preload("res://src/features/defense/domain/defense_skill_effects.gd")
var w
var effects
var motion
const Factory = preload("res://src/features/defense/domain/defense_projectile_factory.gd")
const Geometry = preload("res://src/features/defense/domain/defense_projectile_geometry.gd")
var factory

func _init(world) -> void:
	w = world
	effects = Effects.new(world)
	motion = Motion.new(world)
	factory = Factory.new(world)

func basic(owner: Dictionary, target: Dictionary, amount: float) -> void:
	factory.basic(owner, target, amount)

func launch(owner: Dictionary, target: Dictionary, definition: Dictionary, origin: Vector2, delay: int) -> void:
	factory.launch(owner, target, definition, origin, delay)

func tick() -> void:
	w.skills.fireball.tick()
	var active: Array = w.missiles.duplicate()
	for p: Dictionary in active:
		if p.ended or w.time_ms < p.start:
			continue
		var owner: Dictionary = w.units.get(p.owner, {})
		if owner.is_empty() or (owner.dead and not p.skill.get("death_cast", false)) or w.time_ms >= p.expires:
			p.ended = true
			continue
		var target: Dictionary = w.units.get(p.target, {})
		if p.skill.has("ice_rain"):
			w.skills.ice.rain_tick(p, owner)
			continue
		if p.kind == 3 and p.forever:
			p.expires = w.time_ms + 15000
			if not owner.skills.has(int(p.skill.__id__)):
				p.ended = true
				continue
		if not p.fired and p.kind != 0:
			p.fired = true
			var begin_skill: Dictionary = p.skill.duplicate(true)
			begin_skill["spawn_position"] = true
			begin_skill["spawn_point"] = p.to if p.kind == 1 else p.pos
			effects.apply(owner, target if not target.is_empty() else {"id": 0, "pos": p.pos, "dead": false}, begin_skill)
			var logic_pos: Vector2 = p.to if p.kind == 1 else p.pos
			w.skills.chain(owner, p.skill, 12, target, logic_pos)
			w.skills.chain(owner, p.skill, 15, target, p.from)
			if p.skill.get("cd_fire", true):
				w.skills.chain(owner, p.skill, 13, target, logic_pos)
				w.skills.chain(owner, p.skill, 16, target, p.from)
		if not target.is_empty() and not target.dead and p.kind in [0, 1, 5, 7]:
			p.to = w.targets.attack_point(target)
		if p.kind == 0:
			p.pos = p.pos.move_toward(p.to, p.speed * 0.016)
			p.rotation = p.pos.direction_to(p.to).angle() + PI / 2
			if p.pos.distance_to(p.to) <= 15:
				if not target.is_empty() and not target.dead:
					w.damage.basic_hit(owner, target, p.amount)
					w.skills.trigger(owner, "attack", target)
					w.skills.trigger(target, "physical_hurt", owner)
				p.ended = true
		elif p.kind in [1, 9, 21, 29, 30, 33, 37]:
			if p.charge_end > 0 and w.time_ms >= p.charge_end:
				p.ended = true
			else:
				motion.moving(p, owner, target)
		elif p.kind == 10:
			p.pos = p.pos.move_toward(p.to, p.speed * 0.016)
			if w.time_ms >= p.at:
				p.ended = true
		elif p.kind in [2, 6]:
			if p.skill.get("persistent_area", false):
				if w.time_ms >= p.at:
					pulse(p, owner, target, true)
				continue
			if not p.applied and w.time_ms >= p.at:
				pulse(p, owner, target, p.kind == 2)
				p.applied = true
			p.ended = p.applied and w.time_ms >= p.start + p.area_life
		elif p.kind == 7:
			if target.is_empty() or target.dead:
				p.ended = true
			else:
				if p.remaining > 0 or p.forever:
					var remaining: int = p.remaining
					pulse(p, owner, target, false)
					if remaining > 0 and p.remaining <= 0:
						p.visual_until = w.time_ms + p.area_life
				p.from = w.targets.attack_point(owner)
				p.pos = w.targets.attack_point(target)
				p.to = p.pos
				p.rotation = p.from.direction_to(p.to).angle() + PI / 2
				p.ended = not p.forever and p.remaining <= 0 and w.time_ms >= p.visual_until
		elif p.kind in [12, 14]:
			if (target.is_empty() or target.dead or (p.kind == 14 and p.pos.distance_to(p.to) < 10)):
				var next: Dictionary = {}
				if p.kind == 14:
					var pool: Array = w.targets.area(owner, p.pos, 3000, p.allies)
					if not pool.is_empty():
						next = pool[w.rng.stream("defense.combat").next_int(pool.size())]
				else:
					next = w.targets.nearest({"id": owner.id, "side": owner.side, "pos": p.pos}, 3000)
				if not next.is_empty():
					p.target = next.id
					p.to = next.pos
			elif p.kind == 12:
				p.to = target.pos
			p.pos = p.pos.move_toward(p.to, p.speed * 0.016)
			pulse(p, owner, target, true)
		elif p.kind in [4, 5]:
			p.from = w.targets.attack_point(owner)
			if p.kind == 5:
				p.direction = p.from.direction_to(p.to)
			p.to = p.from + p.direction * float(p.shape.get("baseSize", {}).get("y", 500)) * 4.0
			p.pos = p.from
			p.rotation = p.direction.angle() + PI / 2
			pulse(p, owner, target, true)
		elif p.kind == 3:
			if target.is_empty() or target.dead:
				p.ended = true
			else:
				p.pos = target.pos
				pulse(p, owner, target, true)
		elif p.kind == 17:
			var angle: float = (w.time_ms - p.start) * float(p.skill.get("damage_interval", 180)) / 1000.0 * PI / 180
			p.pos = w.targets.attack_point(owner)
			p.rotation = p.direction.angle() + PI / 2 + angle
			var overlaps: Array = []
			for u in Geometry.recipients(w, p, owner):
				overlaps.append(u.id)
				if not p.hits.has(u.id):
					impact(p, owner, u)
			p.hits = overlaps
			p.ended = w.time_ms >= p.orbit_end
		elif p.kind == 31:
			p.radius = p.full_radius * clampf(float(w.time_ms - p.start) / p.life, 0, 1)
			pulse(p, owner, target, true)
			p.ended = w.time_ms - p.start >= p.life
		else:
			pulse(p, owner, target, p.kind in [2, 3, 15, 20])
		if p.ended and p.kind != 0:
			w.skills.chain(owner, p.skill, 2, target, p.pos)
			w.skills.chain(owner, p.skill, 10, target, p.pos)
			w.skills.chain(owner, p.skill, 17, target, p.from)
			w.skills.fire.repeat_end(p, owner, target)
	w.missiles = w.missiles.filter(func(p): return not p.ended)

func pulse(p: Dictionary, owner: Dictionary, target: Dictionary, area: bool) -> void:
	if w.time_ms < p.at:
		return
	p.at += p.interval
	p.remaining -= 1
	if p.wall:
		w.damage.apply_wall(owner, p.skill)
	elif area:
		if p.kind == 15:
			p.pos = w.targets.attack_point(owner)
		var recipients: Array = Geometry.recipients(w, p, owner)
		for u in recipients:
			impact(p, owner, u)
	elif not target.is_empty() and not target.dead:
		impact(p, owner, target)
		if p.kind in [7, 35]:
			p.from = owner.pos
			p.pos = target.pos
	else:
		if p.kind == 6:
			effects.apply(owner, {"id": 0, "pos": p.pos, "dead": false}, p.skill, "pre")
		p.ended = true
	if p.kind == 35 and not target.is_empty():
		p.hits.append(target.id)
		var next_targets: Array = w.targets.area(owner, target.pos, float(p.skill.get("attack_range", 400)))
		next_targets.sort_custom(func(a, b): return target.pos.distance_squared_to(a.pos) < target.pos.distance_squared_to(b.pos))
		var found = false
		for candidate in next_targets:
			if not p.hits.has(candidate.id):
				p.from = target.pos
				p.target = candidate.id
				p.to = candidate.pos
				found = true
				break
		if not found:
			p.ended = true
	w.skills.chain(owner, p.skill, 8, target, owner.pos, p.id)
	w.skills.chain(owner, p.skill, 11, target, p.pos, p.id)
	if p.remaining <= 0 and p.kind not in [7, 31] and not p.forever:
		p.ended = true

func impact(p: Dictionary, owner: Dictionary, target: Dictionary) -> void:
	if p.skill.has("ice_shot"):
		w.skills.ice.impact(p, owner, target)
		return
	if p.skill.has("fireball_payload"):
		w.skills.fireball.impact(owner, target, p.skill.fireball_payload)
		return
	if p.skill.get("fireball_ember", false) and not w.skills.fireball.ember_ready(owner, target, int(p.at) - int(p.interval)):
		return
	effects.apply(owner, target, p.skill, "pre")
	if target.dead:
		return
	var before = U.hp(target)
	w.damage.apply_skill(owner, target, p.skill)
	effects.apply(owner, target, p.skill, "post", maxf(0, before - U.hp(target)))
	if p.attack_index == 0:
		w.skills.chain(owner, p.skill, 1, target, target.pos)
		w.skills.chain(owner, p.skill, 6, target, owner.pos)
	p.attack_index += 1
	w.skills.chain(owner, p.skill, 3, target, target.pos)
	w.skills.chain(owner, p.skill, 4, target, target.pos)
	w.skills.chain(owner, p.skill, 7, target, owner.pos)
	if target.dead:
		w.skills.chain(owner, p.skill, 9, target, target.pos)

