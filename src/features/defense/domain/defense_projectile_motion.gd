class_name DefenseProjectileMotion
extends RefCounted

const Ballistics = preload("res://src/features/defense/domain/defense_ballistics.gd")
const Geometry = preload("res://src/features/defense/domain/defense_projectile_geometry.gd")

var w

func _init(world) -> void:
	w = world

func moving(p: Dictionary, owner: Dictionary, target: Dictionary) -> void:
	if p.kind == 1:
		curved(p, owner, target)
		return
	if p.kind == 33:
		if w.time_ms < p.fly_until:
			p.pos += p.direction * p.speed * 0.016
		else:
			w.projectiles.pulse(p, owner, target, true)
		return
	if w.time_ms < p.at:
		return
	if p.kind in [9, 29, 30, 37]:
		if p.direction == Vector2.ZERO:
			p.direction = Vector2.UP if owner.side == 1 else Vector2.DOWN
		var before: Vector2 = p.pos
		p.pos += p.direction * p.speed * 0.016
		var after: Vector2 = p.pos
		p.rotation = p.direction.angle() + PI / 2
		if p.kind in [29, 30]:
			owner.pos = p.pos + p.owner_offset
		for contact in Geometry.swept(w, p, owner, before):
			if p.hits.size() >= p.hit_limit:
				break
			var u: Dictionary = contact.unit
			if u.dead or w.targets.hidden_enemy(owner, u):
				continue
			p.pos = before.lerp(after, contact.fraction)
			p.hits.append(u.id)
			w.projectiles.impact(p, owner, u)
		if p.hits.size() < p.hit_limit:
			p.pos = after
		move_chain(p, owner, target, p.speed * 0.016)
		if p.pos.y < -200 or p.pos.y > w.combat.world.bottom + 200 or p.pos.x < 150 or p.pos.x > 1450 or p.hits.size() >= p.hit_limit:
			p.ended = true
		return
	p.pos = p.pos.move_toward(p.to, p.speed * 0.016)
	p.rotation = p.pos.direction_to(p.to).angle() + PI / 2
	if p.pos.distance_to(p.to) <= 15:
		if p.kind == 21:
			for u in w.targets.area(owner, p.to, p.radius, p.allies):
				w.projectiles.impact(p, owner, u)
			p.ended = true
			return
		if not target.is_empty() and not target.dead:
			w.projectiles.impact(p, owner, target)
		elif p.kind == 10:
			for u in w.targets.area(owner, p.to, p.radius):
				w.projectiles.impact(p, owner, u)
		p.ended = true

func curved(p: Dictionary, owner: Dictionary, target: Dictionary) -> void:
	var before = Ballistics.step(p)
	if not target.is_empty() and not target.dead:
		var closest = Geometry2D.get_closest_point_to_segment(target.pos, before, p.pos)
		if closest.distance_squared_to(target.pos) <= 32 * 32 or p.curve_t >= 1:
			w.projectiles.impact(p, owner, target)
			p.ended = true
	elif p.curve_t >= 1:
		var recipient = w.targets.nearest({"id": owner.id, "side": owner.side, "pos": p.to}, 50)
		if not recipient.is_empty():
			w.projectiles.impact(p, owner, recipient)
		p.ended = true

func move_chain(p: Dictionary, owner: Dictionary, target: Dictionary, distance: float) -> void:
	if p.kind not in [29, 37]:
		return
	p.travelled += distance
	while p.travelled >= 50:
		p.travelled -= 50
		w.skills.chain(owner, p.skill, 14, target, p.pos)


